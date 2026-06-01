# CZT Neutron Tomography

**Author:** Edcer Laguda  
**Affiliation:** McMaster University, Department of Physics and Astronomy  
**Program:** Ph.D. in Medical Physics  
**Supervisor:** Dr. Soo Hyun Byun

---

## Overview

This repository contains software and analysis tools developed for neutron imaging and neutron tomography using a cadmium zinc telluride (CZT) detector system.

The software was developed as part of a Ph.D. research project at McMaster University investigating neutron radiography, neutron tomography, detector characterization, image reconstruction, and event-based neutron imaging.

---

## Repository Structure

```text
ASTRA/
    astra_recon.py
    view_iteration_study_advanced.py
    README.md

README.md
LICENSE
.gitignore
```

---

## Software Components

### ASTRA Reconstruction

The ASTRA reconstruction script performs tomographic reconstruction from neutron attenuation projections using:

- CGLS reconstruction
- SIRT reconstruction

Supported configurations:

```text
CGLS10
CGLS20
CGLS50
CGLS100
SIRT100
SIRT200
SIRT300
```

### Interactive Volume Viewer

The visualization tool provides:

- Axial slice visualization
- Coronal slice visualization
- Sagittal slice visualization
- Contrast adjustment
- Reconstruction comparison
- Denoising comparison

Supported denoising methods:

```text
None
Gaussian
Median
NLM
TV
```

---

## Requirements

Python 3.x

Required packages:

```bash
pip install numpy scipy matplotlib
```

ASTRA Toolbox:

```bash
pip install astra-toolbox
```

---

## Running the Software

Reconstruction:

```bash
python ASTRA/astra_recon.py
```

Visualization:

```bash
python ASTRA/view_iteration_study_advanced.py
```

---

## Citation

If this software is used in academic work, please cite:

Laguda, E.

*Development of a CZT-Based Neutron Imaging Detector for Neutron Radiography and Tomography.*

Ph.D. Thesis, McMaster University, 2026.

### Research Supervision

This work was conducted under the supervision of:

- Dr. Soo Hyun Byun, McMaster University
- Dr. Troy Farncombe, McMaster University

The author gratefully acknowledges the guidance, mentorship, and support provided by Dr. Byun and Dr. Farncombe throughout the development of this research and the associated simulation framework.
