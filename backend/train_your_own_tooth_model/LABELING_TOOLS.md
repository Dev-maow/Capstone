# Labeling Tools

For this project, the best labeling tools are:

## 1. CVAT

Recommended if:
- you want the most reliable polygon labeling workflow
- you may label hundreds of images
- you might work with other people

Why it is good:
- excellent polygon tools
- supports segmentation tasks well
- export options are strong

Downside:
- a bit heavier to set up than lightweight tools

Website:
- [CVAT](https://www.cvat.ai/)

## 2. Label Studio

Recommended if:
- you want a modern UI
- you want local labeling with flexible setup

Why it is good:
- nice interface
- easy to review labels
- good for teams too

Downside:
- you need to be a little careful with export formatting

Website:
- [Label Studio](https://labelstud.io/)

## 3. Roboflow Annotate

Recommended if:
- you want the fastest start
- you want simple browser-based polygon annotation

Why it is good:
- easy to use
- very quick for small projects
- can export YOLO segmentation labels

Downside:
- cloud workflow may not be ideal for private data

Website:
- [Roboflow](https://roboflow.com/)

## My Recommendation For You

If you want the easiest path:
- use `Roboflow Annotate`

If you want the strongest long-term workflow:
- use `CVAT`

## Export Format You Want

For this training scaffold, export to:
- `YOLO Segmentation`

Classes:
- `upper_teeth`
- `lower_teeth`

## Labeling Rule Reminder

- only visible tooth enamel
- never label gums, lips, tongue, or dark mouth cavity
- if lower teeth are not visible, leave lower unlabeled
- if no teeth are visible, empty label file

