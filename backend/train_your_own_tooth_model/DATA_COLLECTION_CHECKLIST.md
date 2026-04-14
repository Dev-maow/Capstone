# Data Collection Checklist

Use this checklist when gathering images for the first version of the model.

## Classes

- `upper_teeth`
- `lower_teeth`

## First Dataset Goal

Starter target:
- 200 to 400 images total

Suggested split:
- 80% train
- 20% val

## Must-Have Image Types

- front smile with upper teeth visible
- front smile with upper and lower teeth visible
- slight head tilt left
- slight head tilt right
- wider smile
- small smile
- close camera distance
- medium camera distance
- bright indoor light
- soft natural light

## Very Important Hard Cases

- open mouth but no visible teeth
- lips covering lower teeth
- teeth partly covered by lips
- side smile
- blurred image
- overexposed teeth
- underexposed mouth
- tongue visible
- dark mouth cavity
- printed photo on screen

These are important because they teach the model not to hallucinate teeth.

## Diversity Checklist

Collect variation in:
- skin tone
- age
- tooth color
- smile shape
- face angle
- camera quality
- lighting

## What To Avoid At First

- tiny images
- extreme filters
- heavy compression
- very messy backgrounds if you can avoid them

## Good Naming Pattern

Use simple filenames:

```text
smile_0001.jpg
smile_0002.jpg
smile_0003.jpg
```

Matching labels:

```text
smile_0001.txt
smile_0002.txt
smile_0003.txt
```

## First 20 Images Plan

Gather:
- 8 normal front smiles
- 4 tilted smiles
- 4 partial-teeth smiles
- 4 hard negatives with open mouth but no teeth

That first 20-image batch is enough to test the full labeling and training pipeline.

