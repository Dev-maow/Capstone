package com.example.dentalogic;

import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * MainActivity bridges Flutter ↔ native MediaPipe.
 *
 * Channels:
 *   com.dentalogic/ar_control  (MethodChannel)  — start/stop landmark detection
 *   com.dentalogic/ar_landmarks (EventChannel)  — streams landmark data to Flutter
 */
public class MainActivity extends FlutterActivity {

    private static final String TAG             = "DentaLogic_Main";
    private static final String METHOD_CHANNEL  = "com.dentalogic/ar_control";
    private static final String EVENT_CHANNEL   = "com.dentalogic/ar_landmarks";

    private FaceLandmarkDetector detector;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // ── EventChannel: streams landmark results to Flutter ──
        new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                EVENT_CHANNEL
        ).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object args, EventChannel.EventSink events) {
                Log.i(TAG, "EventChannel: Flutter started listening");
                if (detector == null) {
                    detector = new FaceLandmarkDetector(getApplicationContext());
                }
                detector.setEventSink(events);
            }

            @Override
            public void onCancel(Object args) {
                Log.i(TAG, "EventChannel: Flutter cancelled");
                if (detector != null) detector.setEventSink(null);
            }
        });

        // ── MethodChannel: Flutter calls to start/stop detection ──
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                METHOD_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "initialize":
                    handleInitialize(result);
                    break;
                case "processFrame":
                    handleProcessFrame(call, result);
                    break;
                case "dispose":
                    handleDispose(result);
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    private void handleInitialize(MethodChannel.Result result) {
        try {
            if (detector == null) {
                detector = new FaceLandmarkDetector(getApplicationContext());
            }
            boolean success = detector.initialize();
            if (success) {
                Log.i(TAG, "Detector initialized OK");
                result.success(true);
            } else {
                Log.w(TAG, "Detector init failed — model file may be missing");
                result.success(false);
            }
        } catch (Exception e) {
            Log.e(TAG, "Initialize error: " + e.getMessage());
            result.error("INIT_ERROR", e.getMessage(), null);
        }
    }

    private void handleDispose(MethodChannel.Result result) {
        if (detector != null) {
            detector.close();
            detector = null;
        }
        result.success(true);
    }

    private void handleProcessFrame(MethodCall call, MethodChannel.Result result) {
        try {
            if (detector == null) {
                result.success(false);
                return;
            }

            byte[] bytes = call.argument("bytes");
            Number width = call.argument("width");
            Number height = call.argument("height");
            Number rotation = call.argument("rotation");
            Boolean isFrontCamera = call.argument("isFrontCamera");

            if (bytes == null || width == null || height == null || rotation == null) {
                result.success(false);
                return;
            }

            detector.processFrame(
                    bytes,
                    width.intValue(),
                    height.intValue(),
                    rotation.intValue(),
                    Boolean.TRUE.equals(isFrontCamera)
            );
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Process frame error: " + e.getMessage());
            result.error("FRAME_ERROR", e.getMessage(), null);
        }
    }

    @Override
    protected void onDestroy() {
        if (detector != null) {
            detector.close();
            detector = null;
        }
        super.onDestroy();
    }

    /** Called from camera image analysis use-case (set up in Flutter via MethodChannel) */
    public FaceLandmarkDetector getDetector() {
        return detector;
    }
}
