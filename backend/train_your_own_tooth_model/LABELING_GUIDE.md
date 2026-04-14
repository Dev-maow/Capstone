# Labeling Guide

Use this guide to keep labels consistent.

## Classes

- `upper_teeth`
- `lower_teeth`

## What To Include

- visible tooth enamel only
- front-facing visible tooth surfaces

## What Not To Include

- lips
- gums
- tongue
- inner mouth darkness
- cheek highlights
- specular glare outside the tooth boundary

## Rules

1. If only upper teeth are visible, label only upper teeth.
2. If only lower teeth are visible, label only lower teeth.
3. If no teeth are visible, leave the label file empty.
4. Do not estimate hidden teeth.
5. When in doubt, label less, not more.

## Hard Cases

For these, keep labels conservative:
- teeth partly covered by lips
- side smile
- tilted face
- overexposed teeth
- braces reflections
- shadows
- printed images on screens

## Minimum Dataset Recommendation

Starter:
- 300 train
- 60 val

Better:
- 1000+ train
- 200+ val

Include at least:
- 20% side-tilted smiles
- 20% partial/no lower teeth visibility
- 20% hard negatives with open mouth but no visible teeth

