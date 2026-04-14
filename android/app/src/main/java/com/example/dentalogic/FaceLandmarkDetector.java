package com.example.dentalogic;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.graphics.Color;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.camera.core.ExperimentalGetImage;
import androidx.camera.core.ImageProxy;

import com.google.mediapipe.framework.image.BitmapImageBuilder;
import com.google.mediapipe.framework.image.MPImage;
import com.google.mediapipe.tasks.core.BaseOptions;
import com.google.mediapipe.tasks.vision.core.RunningMode;
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker;
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult;
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.io.FileOutputStream;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.FlutterInjector;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

/**
 * MediaPipe Face Landmark Detector
 *
 * Uses MediaPipe FaceLandmarker to detect 478 face landmarks in real-time.
 * Extracts the upper/lower lip and mouth-region landmarks that surround the
 * teeth area, then streams normalized coordinates back to Flutter via EventChannel.
 *
 * Tooth-region landmark indices (MediaPipe 478-point model):
 *   Upper lip inner: 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95
 *   Lower lip inner: 78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308, 415, 310, 311, 312
 *   Upper teeth visible: 191, 80, 81, 82, 13, 312, 311, 310, 415
 *   Lower teeth visible: 375, 321, 405, 314, 17, 84, 181, 91, 146
 *   Lip corners: 61 (left), 291 (right)
 *   Upper lip top: 0, 267, 269, 270, 409, 291
 *   Lower lip bottom: 17, 84, 181, 91, 146, 375
 */
public class FaceLandmarkDetector {
    private static final String TAG = "DentaLogic_FaceLM";
    private static final String MODEL_FILE = "face_landmarker.task";

    // Tooth region landmark indices from MediaPipe 478-point canonical face mesh
    // These form a polygon around the visible tooth area
    private static final int[] UPPER_TOOTH_LANDMARKS = {191, 80, 81, 82, 13, 312, 311, 310, 415};
    private static final int[] LOWER_TOOTH_LANDMARKS = {375, 321, 405, 314, 17, 84, 181, 91, 146};
    private static final int[] UPPER_OUTER_LIP = {61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291};
    private static final int[] LOWER_OUTER_LIP = {61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291};
    private static final int LIP_LEFT  = 61;
    private static final int LIP_RIGHT = 291;
    private static final int UPPER_LIP_TOP    = 0;
    private static final int LOWER_LIP_BOTTOM = 17;

    private FaceLandmarker faceLandmarker;
    private final Context context;
    private EventChannel.EventSink eventSink;
    private boolean isInitialized = false;

    // Keep the latest bitmap so we can run on-device tooth detection in handleResult.
    private final Object bitmapLock = new Object();
    private Bitmap lastFrameBitmap = null;
    private long lastFrameTsMs = 0L;

    // Throttle tooth detection to keep realtime performance.
    private long lastToothDetectTsMs = 0L;
    private static final long TOOTH_DETECT_INTERVAL_MS = 90L;
    private Map<String, Object> lastOnDeviceToothScan = null;

    public FaceLandmarkDetector(Context context) {
        this.context = context;
    }

    public void setEventSink(EventChannel.EventSink sink) {
        this.eventSink = sink;
    }

    /**
     * Initialize MediaPipe FaceLandmarker.
     * The model file must be in assets/models/face_landmarker.task
     * Download from: https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
     */
    public boolean initialize() {
        try {
            // Copy model from assets to cache dir (MediaPipe requires file path, not asset stream)
            File modelFile = copyAssetToCache(MODEL_FILE);
            if (modelFile == null) {
                Log.e(TAG, "Failed to copy model file from assets");
                return false;
            }

            BaseOptions baseOptions = BaseOptions.builder()
                    .setModelAssetPath(modelFile.getAbsolutePath())
                    .build();

            FaceLandmarker.FaceLandmarkerOptions options = FaceLandmarker.FaceLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setNumFaces(1)
                    .setMinFaceDetectionConfidence(0.5f)
                    .setMinFacePresenceConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .setResultListener(this::handleResult)
                    .setErrorListener((error) -> Log.e(TAG, "FaceLandmarker error: " + error))
                    .build();

            faceLandmarker = FaceLandmarker.createFromOptions(context, options);
            isInitialized = true;
            Log.i(TAG, "FaceLandmarker initialized successfully");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to initialize FaceLandmarker: " + e.getMessage());
            return false;
        }
    }

    /**
     * Process a camera frame. Call this for every frame from the camera.
     * Results are delivered asynchronously via handleResult().
     */
    @ExperimentalGetImage
    public void processFrame(ImageProxy imageProxy) {
        if (!isInitialized || faceLandmarker == null) {
            imageProxy.close();
            return;
        }
        try {
            Bitmap bitmap = imageProxyToBitmap(imageProxy);
            if (bitmap == null) {
                imageProxy.close();
                return;
            }
            MPImage mpImage = new BitmapImageBuilder(bitmap).build();
            faceLandmarker.detectAsync(mpImage, imageProxy.getImageInfo().getTimestamp());
        } catch (Exception e) {
            Log.e(TAG, "Error processing frame: " + e.getMessage());
        } finally {
            imageProxy.close();
        }
    }

    public void processFrame(byte[] nv21Bytes, int width, int height, int rotationDegrees, boolean mirror) {
        if (!isInitialized || faceLandmarker == null || nv21Bytes == null) {
            return;
        }

        try {
            Bitmap bitmap = nv21ToBitmap(nv21Bytes, width, height, rotationDegrees, mirror);
            if (bitmap == null) return;

            synchronized (bitmapLock) {
                lastFrameBitmap = bitmap;
                lastFrameTsMs = System.currentTimeMillis();
            }

            MPImage mpImage = new BitmapImageBuilder(bitmap).build();
            faceLandmarker.detectAsync(mpImage, System.currentTimeMillis());
        } catch (Exception e) {
            Log.e(TAG, "Error processing raw frame: " + e.getMessage());
        }
    }

    /**
     * MediaPipe result callback.
     * Extracts tooth-region landmarks and sends to Flutter as a Map.
     */
    private void handleResult(FaceLandmarkerResult result, MPImage image) {
        if (result.faceLandmarks().isEmpty()) {
            sendToFlutter(buildNoFaceResult());
            return;
        }

        List<NormalizedLandmark> landmarks = result.faceLandmarks().get(0);
        Map<String, Object> data = new HashMap<>();
        data.put("faceDetected", true);

        // Provide the actual image dimensions MediaPipe ran on.
        // This is required for correct landmark-to-preview mapping in Flutter.
        int frameW = 0;
        int frameH = 0;
        synchronized (bitmapLock) {
            if (lastFrameBitmap != null) {
                frameW = lastFrameBitmap.getWidth();
                frameH = lastFrameBitmap.getHeight();
            }
        }
        data.put("frameWidth", frameW);
        data.put("frameHeight", frameH);

        // Extract lip corners for mouth width
        NormalizedLandmark lipLeft  = landmarks.get(LIP_LEFT);
        NormalizedLandmark lipRight = landmarks.get(LIP_RIGHT);
        data.put("lipLeftX",  (double) lipLeft.x());
        data.put("lipLeftY",  (double) lipLeft.y());
        data.put("lipRightX", (double) lipRight.x());
        data.put("lipRightY", (double) lipRight.y());

        // Extract upper lip top edge
        NormalizedLandmark upperLipTop = landmarks.get(UPPER_LIP_TOP);
        data.put("upperLipTopY", (double) upperLipTop.y());

        // Extract lower lip bottom edge
        NormalizedLandmark lowerLipBot = landmarks.get(LOWER_LIP_BOTTOM);
        data.put("lowerLipBottomY", (double) lowerLipBot.y());

        // Extract upper tooth polygon points
        List<Double> upperPtsX = new ArrayList<>();
        List<Double> upperPtsY = new ArrayList<>();
        List<Double> upperPtsZ = new ArrayList<>();
        for (int idx : UPPER_TOOTH_LANDMARKS) {
            if (idx < landmarks.size()) {
                upperPtsX.add((double) landmarks.get(idx).x());
                upperPtsY.add((double) landmarks.get(idx).y());
                upperPtsZ.add((double) landmarks.get(idx).z());
            }
        }
        data.put("upperToothX", upperPtsX);
        data.put("upperToothY", upperPtsY);
        data.put("upperToothZ", upperPtsZ);

        // Extract lower tooth polygon points
        List<Double> lowerPtsX = new ArrayList<>();
        List<Double> lowerPtsY = new ArrayList<>();
        List<Double> lowerPtsZ = new ArrayList<>();
        for (int idx : LOWER_TOOTH_LANDMARKS) {
            if (idx < landmarks.size()) {
                lowerPtsX.add((double) landmarks.get(idx).x());
                lowerPtsY.add((double) landmarks.get(idx).y());
                lowerPtsZ.add((double) landmarks.get(idx).z());
            }
        }
        data.put("lowerToothX", lowerPtsX);
        data.put("lowerToothY", lowerPtsY);
        data.put("lowerToothZ", lowerPtsZ);

        List<Double> upperLipX = new ArrayList<>();
        List<Double> upperLipY = new ArrayList<>();
        for (int idx : UPPER_OUTER_LIP) {
            if (idx < landmarks.size()) {
                upperLipX.add((double) landmarks.get(idx).x());
                upperLipY.add((double) landmarks.get(idx).y());
            }
        }
        data.put("upperLipOuterX", upperLipX);
        data.put("upperLipOuterY", upperLipY);

        List<Double> lowerLipX = new ArrayList<>();
        List<Double> lowerLipY = new ArrayList<>();
        for (int idx : LOWER_OUTER_LIP) {
            if (idx < landmarks.size()) {
                lowerLipX.add((double) landmarks.get(idx).x());
                lowerLipY.add((double) landmarks.get(idx).y());
            }
        }
        data.put("lowerLipOuterX", lowerLipX);
        data.put("lowerLipOuterY", lowerLipY);

        // Compute bounding box of the full tooth region
        double minX = Math.min(lipLeft.x(), lipRight.x());
        double maxX = Math.max(lipLeft.x(), lipRight.x());
        double minY = (double) upperLipTop.y();
        double maxY = (double) lowerLipBot.y();
        data.put("toothBboxX",  minX);
        data.put("toothBboxY",  minY);
        data.put("toothBboxW",  maxX - minX);
        data.put("toothBboxH",  maxY - minY);

        // On-device per-tooth detection (offline). Throttled for performance.
        long now = System.currentTimeMillis();
        if (now - lastToothDetectTsMs >= TOOTH_DETECT_INTERVAL_MS) {
            lastToothDetectTsMs = now;
            Bitmap bitmap = null;
            synchronized (bitmapLock) {
                if (lastFrameBitmap != null) bitmap = lastFrameBitmap;
            }
            if (bitmap != null) {
                try {
                    Map<String, Object> scan = detectTeethOnDevice(
                            bitmap,
                            (double) minX,
                            (double) minY,
                            (double) (maxX - minX),
                            (double) (maxY - minY)
                    );
                    if (scan != null) {
                        lastOnDeviceToothScan = scan;
                    }
                } catch (Exception e) {
                    // Never break the landmark stream on detector failure.
                    Log.w(TAG, "On-device tooth detect failed: " + e.getMessage());
                }
            }
        }

        // Always attach latest scan (even if throttled this frame).
        if (lastOnDeviceToothScan != null) {
            data.put("onDeviceToothScan", lastOnDeviceToothScan);
        }

        sendToFlutter(data);
    }

    /**
     * Lightweight on-device tooth detection based on brightness/low-saturation masking
     * + column band splitting. Returns a map shaped like the backend ScanTeethResponse:
     * { imageWidth, imageHeight, confidence, teeth: [ {id,jaw,confidence,polygon:[{x,y}...]} ] }
     */
    private Map<String, Object> detectTeethOnDevice(
            Bitmap full,
            double toothBboxX,
            double toothBboxY,
            double toothBboxW,
            double toothBboxH
    ) {
        final int w = full.getWidth();
        final int h = full.getHeight();
        if (w <= 0 || h <= 0) return null;

        int x0 = clampPx((toothBboxX - 0.08) * w, w);
        int x1 = clampPx((toothBboxX + toothBboxW + 0.08) * w, w);
        int y0 = clampPx((toothBboxY - 0.03) * h, h);
        int y1 = clampPx((toothBboxY + toothBboxH + 0.03) * h, h);
        if (x1 - x0 < 40 || y1 - y0 < 24) return null;

        double midY = toothBboxY + toothBboxH * 0.5;
        int midPx = clampPx(midY * h, h);

        Rect upperRect = new Rect(x0, y0, x1, Math.min(y1, Math.max(y0 + 10, midPx)));
        Rect lowerRect = new Rect(x0, Math.max(y0, Math.min(midPx, y1 - 10)), x1, y1);

        List<Map<String, Object>> teeth = new ArrayList<>();
        float confSum = 0f;
        int confCount = 0;

        List<Map<String, Object>> upper = detectJaw(full, upperRect, "upper");
        for (Map<String, Object> t : upper) { teeth.add(t); confSum += (float) ((double) t.get("confidence")); confCount++; }
        List<Map<String, Object>> lower = detectJaw(full, lowerRect, "lower");
        for (Map<String, Object> t : lower) { teeth.add(t); confSum += (float) ((double) t.get("confidence")); confCount++; }

        Map<String, Object> out = new HashMap<>();
        out.put("imageWidth", w);
        out.put("imageHeight", h);
        out.put("confidence", confCount == 0 ? 0.0 : (double) (confSum / confCount));
        out.put("teeth", teeth);
        return out;
    }

    private List<Map<String, Object>> detectJaw(Bitmap full, Rect rect, String jaw) {
        int rw = rect.width();
        int rh = rect.height();
        if (rw < 24 || rh < 14) return new ArrayList<>();

        // Crop and downscale for speed.
        Bitmap roi = Bitmap.createBitmap(full, rect.left, rect.top, rw, rh);
        int targetW = Math.min(220, Math.max(120, rw));
        int targetH = Math.min(140, Math.max(70, rh));
        Bitmap small = Bitmap.createScaledBitmap(roi, targetW, targetH, true);

        int sw = small.getWidth();
        int sh = small.getHeight();
        int[] pixels = new int[sw * sh];
        small.getPixels(pixels, 0, sw, 0, 0, sw, sh);

        // Build mask: adaptive bright + low saturation in HSV (percentile-based).
        boolean[] mask = new boolean[sw * sh];
        float[] hsv = new float[3];
        int[] histV = new int[256];
        int[] histS = new int[256];
        int[] histL = new int[256];
        int total = pixels.length;
        for (int i = 0; i < pixels.length; i++) {
            int c = pixels[i];
            int r = Color.red(c);
            int g = Color.green(c);
            int b = Color.blue(c);
            Color.RGBToHSV(r, g, b, hsv);
            int s = clampByte(hsv[1] * 255f);
            int v = clampByte(hsv[2] * 255f);
            int luma = clampByte(0.2126f * r + 0.7152f * g + 0.0722f * b);
            histS[s]++; histV[v]++; histL[luma]++;
        }
        int brightThresh = jaw.equals("upper") ? percentileFromHist(histL, total, 68) : percentileFromHist(histL, total, 70);
        int valueThresh = jaw.equals("upper") ? percentileFromHist(histV, total, 62) : percentileFromHist(histV, total, 64);
        int satThresh = percentileFromHist(histS, total, 55);
        brightThresh = Math.max(125, brightThresh);
        valueThresh = Math.max(105, valueThresh);
        satThresh = Math.max(95, satThresh);

        int brightCount = 0;
        for (int i = 0; i < pixels.length; i++) {
            int c = pixels[i];
            int r = Color.red(c);
            int g = Color.green(c);
            int b = Color.blue(c);
            Color.RGBToHSV(r, g, b, hsv);
            int s = clampByte(hsv[1] * 255f);
            int v = clampByte(hsv[2] * 255f);
            int luma = clampByte(0.2126f * r + 0.7152f * g + 0.0722f * b);

            boolean on = (luma >= brightThresh) && (v >= valueThresh) && (s <= satThresh);
            mask[i] = on;
            if (on) brightCount++;
        }
        if (brightCount < 80) return new ArrayList<>();

        // Morphological close(open(mask)) via cheap 3x3 (2 iterations max).
        mask = morphOpen(mask, sw, sh);
        mask = morphClose(mask, sw, sh);

        // Column scores
        float[] col = new float[sw];
        for (int y = 0; y < sh; y++) {
            int row = y * sw;
            for (int x = 0; x < sw; x++) {
                if (mask[row + x]) col[x] += 1f;
            }
        }
        float[] smooth = smooth7(col);
        float thresh = Math.max(sh * 0.10f, percentilePositive(smooth, 35));
        boolean[] activeCols = new boolean[smooth.length];
        for (int i = 0; i < smooth.length; i++) {
            activeCols[i] = smooth[i] >= thresh;
        }
        activeCols = fillSmallGaps(activeCols, Math.max(2, Math.round(sw * 0.018f)));
        List<int[]> bands = findActiveBands(activeCols);
        if (bands.isEmpty()) return new ArrayList<>();

        // Smaller max band width => more splits => closer to per-tooth components.
        int maxBandWidth = Math.max(10, (int) (sw * 0.12f));
        int minBandWidth = Math.max(6, (int) (sw * 0.045f));
        List<int[]> splits = new ArrayList<>();
        for (int[] b : bands) {
            splits.addAll(splitBandByValleys(smooth, b[0], b[1], maxBandWidth, minBandWidth));
        }

        List<Map<String, Object>> out = new ArrayList<>();
        int idx = 1;
        for (int[] seg : splits) {
            int sx0 = Math.max(0, seg[0] - 2);
            int sx1 = Math.min(sw - 1, seg[1] + 2);
            if (sx1 - sx0 < 6) continue;

            // Bounding box of mask points in this band.
            int minX = sw, minY = sh, maxX = -1, maxY = -1;
            int onCount = 0;
            ArrayList<_Pt> pts = new ArrayList<>();
            for (int y = 0; y < sh; y++) {
                int row = y * sw;
                for (int x = sx0; x <= sx1; x++) {
                    if (mask[row + x]) {
                        onCount++;
                        if (x < minX) minX = x;
                        if (x > maxX) maxX = x;
                        if (y < minY) minY = y;
                        if (y > maxY) maxY = y;
                        // downsample points for hull speed
                        if ((onCount % 6) == 0) {
                            pts.add(new _Pt(x, y));
                        }
                    }
                }
            }
            if (onCount < 28 || maxX < 0) continue;

            int bw = maxX - minX + 1;
            int bh = maxY - minY + 1;
            if (bw < sw * 0.030f || bh < sh * 0.16f) continue;

            float areaRatio = onCount / Math.max(1f, (float) (bw * bh));
            double conf = Math.max(0.0, Math.min(0.94, 0.42 + areaRatio * 0.48));

            // Prefer convex hull polygon for a tooth-like outline.
            List<_Pt> hull = convexHull(pts);
            List<Map<String, Object>> poly = new ArrayList<>();
            if (hull.size() >= 3) {
                for (_Pt p : hull) {
                    double fx = rect.left + (p.x / (double) sw) * rect.width();
                    double fy = rect.top + (p.y / (double) sh) * rect.height();
                    poly.add(point(fx, fy, full.getWidth(), full.getHeight()));
                }
            } else {
                // Fallback to bounding rect polygon.
                double fx0 = rect.left + (minX / (double) sw) * rect.width();
                double fx1 = rect.left + ((minX + bw) / (double) sw) * rect.width();
                double fy0 = rect.top + (minY / (double) sh) * rect.height();
                double fy1 = rect.top + ((minY + bh) / (double) sh) * rect.height();
                poly.add(point(fx0, fy0, full.getWidth(), full.getHeight()));
                poly.add(point(fx1, fy0, full.getWidth(), full.getHeight()));
                poly.add(point(fx1, fy1, full.getWidth(), full.getHeight()));
                poly.add(point(fx0, fy1, full.getWidth(), full.getHeight()));
            }

            Map<String, Object> tooth = new HashMap<>();
            tooth.put("id", jaw + "_" + idx);
            tooth.put("jaw", jaw);
            tooth.put("confidence", conf);
            tooth.put("polygon", poly);
            out.add(tooth);
            idx++;
        }

        // Sort by x centroid
        out.sort((a, b) -> {
            double ax = centroidX((List<Map<String, Object>>) a.get("polygon"));
            double bx = centroidX((List<Map<String, Object>>) b.get("polygon"));
            return Double.compare(ax, bx);
        });
        return out;
    }

    private static final class _Pt {
        final int x;
        final int y;
        _Pt(int x, int y) { this.x = x; this.y = y; }
    }

    private static List<_Pt> convexHull(List<_Pt> pts) {
        if (pts == null) return new ArrayList<>();
        if (pts.size() < 3) return new ArrayList<>(pts);

        ArrayList<_Pt> sorted = new ArrayList<>(pts);
        sorted.sort((a, b) -> {
            if (a.x != b.x) return Integer.compare(a.x, b.x);
            return Integer.compare(a.y, b.y);
        });

        ArrayList<_Pt> lower = new ArrayList<>();
        for (_Pt p : sorted) {
            while (lower.size() >= 2 && cross(lower.get(lower.size() - 2), lower.get(lower.size() - 1), p) <= 0) {
                lower.remove(lower.size() - 1);
            }
            lower.add(p);
        }
        ArrayList<_Pt> upper = new ArrayList<>();
        for (int i = sorted.size() - 1; i >= 0; i--) {
            _Pt p = sorted.get(i);
            while (upper.size() >= 2 && cross(upper.get(upper.size() - 2), upper.get(upper.size() - 1), p) <= 0) {
                upper.remove(upper.size() - 1);
            }
            upper.add(p);
        }

        // Concatenate lower + upper, removing duplicate endpoints.
        lower.remove(lower.size() - 1);
        upper.remove(upper.size() - 1);
        ArrayList<_Pt> hull = new ArrayList<>();
        hull.addAll(lower);
        hull.addAll(upper);
        return hull;
    }

    private static long cross(_Pt o, _Pt a, _Pt b) {
        return (long) (a.x - o.x) * (b.y - o.y) - (long) (a.y - o.y) * (b.x - o.x);
    }

    private static Map<String, Object> point(double px, double py, int w, int h) {
        Map<String, Object> p = new HashMap<>();
        p.put("x", Math.max(0.0, Math.min(1.0, px / (double) w)));
        p.put("y", Math.max(0.0, Math.min(1.0, py / (double) h)));
        return p;
    }

    private static double centroidX(List<Map<String, Object>> poly) {
        if (poly == null || poly.isEmpty()) return 0.0;
        double sx = 0.0;
        for (Map<String, Object> p : poly) {
            Object x = p.get("x");
            sx += x instanceof Number ? ((Number) x).doubleValue() : 0.0;
        }
        return sx / poly.size();
    }

    private static int clampPx(double value, int limit) {
        int v = (int) Math.round(value);
        if (v < 0) return 0;
        if (v > limit) return limit;
        return v;
    }

    private static int clampByte(float v) {
        int x = (int) Math.round(v);
        if (x < 0) return 0;
        if (x > 255) return 255;
        return x;
    }

    private static int percentileFromHist(int[] hist, int total, int pct) {
        if (total <= 0) return 0;
        int target = (int) Math.round((pct / 100.0) * total);
        int acc = 0;
        for (int i = 0; i < hist.length; i++) {
            acc += hist[i];
            if (acc >= target) return i;
        }
        return hist.length - 1;
    }

    private static float[] smooth7(float[] in) {
        float[] out = new float[in.length];
        for (int i = 0; i < in.length; i++) {
            float sum = 0f;
            int count = 0;
            for (int k = -3; k <= 3; k++) {
                int j = i + k;
                if (j >= 0 && j < in.length) {
                    sum += in[j];
                    count++;
                }
            }
            out[i] = sum / Math.max(1, count);
        }
        return out;
    }

    private static float percentilePositive(float[] values, int pct) {
        ArrayList<Float> pos = new ArrayList<>();
        for (float v : values) if (v > 0) pos.add(v);
        if (pos.isEmpty()) return 0f;
        pos.sort(Float::compare);
        int idx = (int) Math.round((pct / 100.0) * (pos.size() - 1));
        idx = Math.max(0, Math.min(pos.size() - 1, idx));
        return pos.get(idx);
    }

    private static List<int[]> findBands(float[] scores, float threshold) {
        List<int[]> bands = new ArrayList<>();
        Integer start = null;
        for (int i = 0; i < scores.length; i++) {
            if (scores[i] >= threshold && start == null) {
                start = i;
            } else if (scores[i] < threshold && start != null) {
                if (i - start >= 6) bands.add(new int[]{start, i});
                start = null;
            }
        }
        if (start != null && scores.length - start >= 6) {
            bands.add(new int[]{start, scores.length - 1});
        }
        return bands;
    }

    private static List<int[]> findActiveBands(boolean[] active) {
        List<int[]> bands = new ArrayList<>();
        Integer start = null;
        for (int i = 0; i < active.length; i++) {
            if (active[i] && start == null) {
                start = i;
            } else if (!active[i] && start != null) {
                if (i - start >= 6) bands.add(new int[]{start, i});
                start = null;
            }
        }
        if (start != null && active.length - start >= 6) {
            bands.add(new int[]{start, active.length - 1});
        }
        return bands;
    }

    private static List<int[]> splitBand(int start, int end, int maxWidth) {
        int width = end - start;
        ArrayList<int[]> out = new ArrayList<>();
        if (width <= maxWidth) {
            out.add(new int[]{start, end});
            return out;
        }
        int pieces = Math.max(2, (int) Math.round(width / (double) maxWidth));
        double step = width / (double) pieces;
        for (int i = 0; i < pieces; i++) {
            int s = (int) Math.round(start + i * step);
            int e = (int) Math.round(start + (i + 1) * step);
            if (e - s >= 6) out.add(new int[]{s, e});
        }
        if (out.isEmpty()) out.add(new int[]{start, end});
        return out;
    }

    private static boolean[] fillSmallGaps(boolean[] in, int maxGap) {
        boolean[] out = in.clone();
        Integer start = null;
        for (int i = 0; i < in.length; i++) {
            if (!in[i] && start == null) {
                start = i;
            } else if (in[i] && start != null) {
                if (i - start <= maxGap && start > 0 && in[start - 1]) {
                    for (int j = start; j < i; j++) out[j] = true;
                }
                start = null;
            }
        }
        return out;
    }

    private static List<int[]> splitBandByValleys(float[] smooth, int start, int end, int maxWidth, int minWidth) {
        int width = end - start;
        if (width <= maxWidth) {
            ArrayList<int[]> single = new ArrayList<>();
            single.add(new int[]{start, end});
            return single;
        }
        if (width < minWidth * 2) {
            return splitBand(start, end, maxWidth);
        }

        int searchStart = start + minWidth;
        int searchEnd = end - minWidth;
        if (searchEnd <= searchStart) {
            return splitBand(start, end, maxWidth);
        }

        int valley = searchStart;
        float valleyValue = Float.MAX_VALUE;
        for (int i = searchStart; i < searchEnd; i++) {
            if (smooth[i] < valleyValue) {
                valleyValue = smooth[i];
                valley = i;
            }
        }

        float leftPeak = 0f;
        for (int i = start; i < valley; i++) leftPeak = Math.max(leftPeak, smooth[i]);
        float rightPeak = 0f;
        for (int i = valley; i < end; i++) rightPeak = Math.max(rightPeak, smooth[i]);

        if (Math.min(leftPeak, rightPeak) <= 0f || valleyValue > Math.min(leftPeak, rightPeak) * 0.72f) {
            return splitBand(start, end, maxWidth);
        }

        ArrayList<int[]> out = new ArrayList<>();
        if (valley - start >= minWidth) {
            out.addAll(splitBandByValleys(smooth, start, valley, maxWidth, minWidth));
        }
        if (end - valley >= minWidth) {
            out.addAll(splitBandByValleys(smooth, valley, end, maxWidth, minWidth));
        }
        if (out.isEmpty()) out.add(new int[]{start, end});
        return out;
    }

    private static boolean[] morphOpen(boolean[] in, int w, int h) {
        return dilate(erode(in, w, h), w, h);
    }

    private static boolean[] morphClose(boolean[] in, int w, int h) {
        return erode(dilate(in, w, h), w, h);
    }

    private static boolean[] erode(boolean[] in, int w, int h) {
        boolean[] out = new boolean[in.length];
        for (int y = 1; y < h - 1; y++) {
            int row = y * w;
            for (int x = 1; x < w - 1; x++) {
                int i = row + x;
                boolean ok = true;
                for (int dy = -1; dy <= 1 && ok; dy++) {
                    int r = (y + dy) * w;
                    for (int dx = -1; dx <= 1; dx++) {
                        if (!in[r + (x + dx)]) { ok = false; break; }
                    }
                }
                out[i] = ok;
            }
        }
        return out;
    }

    private static boolean[] dilate(boolean[] in, int w, int h) {
        boolean[] out = new boolean[in.length];
        for (int y = 1; y < h - 1; y++) {
            int row = y * w;
            for (int x = 1; x < w - 1; x++) {
                int i = row + x;
                boolean ok = false;
                for (int dy = -1; dy <= 1 && !ok; dy++) {
                    int r = (y + dy) * w;
                    for (int dx = -1; dx <= 1; dx++) {
                        if (in[r + (x + dx)]) { ok = true; break; }
                    }
                }
                out[i] = ok;
            }
        }
        return out;
    }

    private Map<String, Object> buildNoFaceResult() {
        Map<String, Object> data = new HashMap<>();
        data.put("faceDetected", false);
        return data;
    }

    private void sendToFlutter(Map<String, Object> data) {
        if (eventSink != null) {
            // Must run on main thread
            android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
            mainHandler.post(() -> {
                if (eventSink != null) {
                    eventSink.success(data);
                }
            });
        }
    }

    /** Convert ImageProxy (YUV_420_888) to Bitmap */
    private Bitmap imageProxyToBitmap(ImageProxy imageProxy) {
        try {
            ImageProxy.PlaneProxy[] planes = imageProxy.getPlanes();
            ByteBuffer yBuffer  = planes[0].getBuffer();
            ByteBuffer uBuffer  = planes[1].getBuffer();
            ByteBuffer vBuffer  = planes[2].getBuffer();

            int ySize = yBuffer.remaining();
            int uSize = uBuffer.remaining();
            int vSize = vBuffer.remaining();

            byte[] nv21 = new byte[ySize + uSize + vSize];
            yBuffer.get(nv21, 0, ySize);
            vBuffer.get(nv21, ySize, vSize);
            uBuffer.get(nv21, ySize + vSize, uSize);

            YuvImage yuvImage = new YuvImage(nv21, ImageFormat.NV21,
                    imageProxy.getWidth(), imageProxy.getHeight(), null);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            yuvImage.compressToJpeg(
                    new Rect(0, 0, imageProxy.getWidth(), imageProxy.getHeight()),
                    80, out);

            byte[] imageBytes = out.toByteArray();
            Bitmap bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);

            // Rotate based on sensor rotation
            Matrix matrix = new Matrix();
            matrix.postRotate(imageProxy.getImageInfo().getRotationDegrees());
            return Bitmap.createBitmap(bitmap, 0, 0,
                    bitmap.getWidth(), bitmap.getHeight(), matrix, true);
        } catch (Exception e) {
            Log.e(TAG, "Bitmap conversion error: " + e.getMessage());
            return null;
        }
    }

    private Bitmap nv21ToBitmap(byte[] nv21Bytes, int width, int height, int rotationDegrees, boolean mirror) {
        try {
            YuvImage yuvImage = new YuvImage(nv21Bytes, ImageFormat.NV21, width, height, null);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            yuvImage.compressToJpeg(new Rect(0, 0, width, height), 80, out);

            byte[] imageBytes = out.toByteArray();
            Bitmap bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
            if (bitmap == null) return null;

            Matrix matrix = new Matrix();
            matrix.postRotate(rotationDegrees);
            if (mirror) {
                matrix.postScale(-1f, 1f, bitmap.getWidth() / 2f, bitmap.getHeight() / 2f);
            }

            return Bitmap.createBitmap(
                    bitmap,
                    0,
                    0,
                    bitmap.getWidth(),
                    bitmap.getHeight(),
                    matrix,
                    true
            );
        } catch (Exception e) {
            Log.e(TAG, "NV21 conversion error: " + e.getMessage());
            return null;
        }
    }

    private File copyAssetToCache(String assetName) {
        try {
            String flutterAssetPath = FlutterInjector.instance()
                    .flutterLoader()
                    .getLookupKeyForAsset("assets/models/" + assetName);
            InputStream in = context.getAssets().open(flutterAssetPath);
            File outFile = new File(context.getCacheDir(), assetName);
            if (outFile.exists()) return outFile; // already copied
            FileOutputStream out = new FileOutputStream(outFile);
            byte[] buffer = new byte[4096];
            int read;
            while ((read = in.read(buffer)) != -1) out.write(buffer, 0, read);
            in.close();
            out.close();
            return outFile;
        } catch (IOException e) {
            Log.e(TAG, "Could not copy asset: " + e.getMessage());
            return null;
        }
    }

    public void close() {
        if (faceLandmarker != null) {
            faceLandmarker.close();
            faceLandmarker = null;
        }
        isInitialized = false;
    }
}

    
