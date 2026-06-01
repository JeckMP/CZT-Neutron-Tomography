import os
import re
import glob
import numpy as np
import scipy.io as sio
import astra

DATA_DIR = "data"
OUT_DIR = "output"
os.makedirs(OUT_DIR, exist_ok=True)

RECONS = [
    ("CGLS10", "CGLS", 10),
    ("CGLS20", "CGLS", 20),
    ("CGLS50", "CGLS", 50),
    ("CGLS100", "CGLS", 100),
    ("SIRT100", "SIRT", 100),
    ("SIRT200", "SIRT", 200),
    ("SIRT300", "SIRT", 300),
]

files = sorted(glob.glob(os.path.join(DATA_DIR, "*_Amap.mat")))

angles = []
projections = []

for f in files:
    name = os.path.basename(f)
    m = re.search(r"_(\d+(?:\.\d+)?)_.*Amap\.mat$", name)
    if m is None:
        continue

    mat = sio.loadmat(f)
    Amap = mat["Amap"].astype(np.float32)
    Amap = np.nan_to_num(Amap, nan=0.0, posinf=0.0, neginf=0.0)
    Amap[Amap < 0] = 0

    angles.append(float(m.group(1)))
    projections.append(Amap)

angles = np.array(angles, dtype=np.float32)
projections = np.array(projections, dtype=np.float32)

idx = np.argsort(angles)
angles = angles[idx]
projections = projections[idx]

print("Loaded projections:", len(angles))
print("Angle range:", angles.min(), "to", angles.max())
print("Projection stack:", projections.shape)

n_angles, ny, nx = projections.shape
angles_rad = np.deg2rad(angles)

proj_geom = astra.create_proj_geom("parallel", 1.0, nx, angles_rad)
vol_geom = astra.create_vol_geom(nx, nx)
projector_id = astra.create_projector("linear", proj_geom, vol_geom)

def reconstruct(method, iterations, label):
    volume = np.zeros((ny, nx, nx), dtype=np.float32)

    print(f"\nRunning {label}...")

    for row in range(ny):
        print(f"{label}: slice {row+1}/{ny}")

        sino = projections[:, row, :].astype(np.float32)

        sino_id = astra.data2d.create("-sino", proj_geom, sino)
        recon_id = astra.data2d.create("-vol", vol_geom)

        cfg = astra.astra_dict(method)
        cfg["ProjectorId"] = projector_id
        cfg["ProjectionDataId"] = sino_id
        cfg["ReconstructionDataId"] = recon_id

        alg_id = astra.algorithm.create(cfg)
        astra.algorithm.run(alg_id, iterations)

        volume[row] = astra.data2d.get(recon_id)

        astra.algorithm.delete(alg_id)
        astra.data2d.delete(recon_id)
        astra.data2d.delete(sino_id)

    volume = np.nan_to_num(volume, nan=0.0, posinf=0.0, neginf=0.0)
    return volume

results = {}

for label, method, iterations in RECONS:
    results[label] = reconstruct(method, iterations, label)

astra.projector.delete(projector_id)

results["angles_deg"] = angles
results["input_projections"] = projections

sio.savemat(
    os.path.join(OUT_DIR, "boric_acid_iteration_study.mat"),
    results
)

print("\nDone.")
print("Saved: output/boric_acid_iteration_study.mat")

import scipy.io as sio
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, RadioButtons
from scipy.ndimage import gaussian_filter, median_filter
from skimage.restoration import denoise_tv_chambolle, denoise_nl_means, estimate_sigma

MAT_FILE = "output/boric_acid_iteration_study.mat"

data = sio.loadmat(MAT_FILE)

methods = {
    "CGLS10": data["CGLS10"].astype(np.float32),
    "CGLS20": data["CGLS20"].astype(np.float32),
    "CGLS50": data["CGLS50"].astype(np.float32),
    "CGLS100": data["CGLS100"].astype(np.float32),
    "SIRT100": data["SIRT100"].astype(np.float32),
    "SIRT200": data["SIRT200"].astype(np.float32),
    "SIRT300": data["SIRT300"].astype(np.float32),
}

current_method = "SIRT100"
current_filter = "Median"

def normalize_for_filter(v):
    v = np.nan_to_num(v, nan=0.0, posinf=0.0, neginf=0.0)
    v[v < 0] = 0

    vmax = np.percentile(v, 99.8)
    if vmax <= 0:
        vmax = np.max(v)
    if vmax <= 0:
        vmax = 1.0

    return np.clip(v / vmax, 0, 1)

def prepare_volume(method_name, filter_name):
    v = methods[method_name].copy()
    v = normalize_for_filter(v)

    if filter_name == "None":
        out = v
    elif filter_name == "Gaussian":
        out = gaussian_filter(v, sigma=0.8)
    elif filter_name == "Median":
        out = median_filter(v, size=3)
    elif filter_name == "NLM":
        sigma_est = np.mean(estimate_sigma(v, channel_axis=None))
        out = denoise_nl_means(
            v,
            h=0.8 * sigma_est,
            patch_size=3,
            patch_distance=5,
            fast_mode=True,
            channel_axis=None
        )
    elif filter_name == "TV":
        out = denoise_tv_chambolle(
            v,
            weight=0.08,
            channel_axis=None
        )
    else:
        out = v

    return out.astype(np.float32)

vol = prepare_volume(current_method, current_filter)

ny, nx, nz = vol.shape

y = ny // 2
x = nx // 2
z = nz // 2

vmax0 = np.percentile(vol, 99.5)
if vmax0 <= 0:
    vmax0 = 1.0

fig, axes = plt.subplots(1, 3, figsize=(13, 4))
plt.subplots_adjust(left=0.08, right=0.78, bottom=0.32)

# Correct planes for volume[y, x, z]
im_axial = axes[0].imshow(vol[y, :, :], cmap="gray", vmin=0, vmax=vmax0)
axes[0].set_title(f"Axial y={y}")

im_coronal = axes[1].imshow(vol[:, x, :], cmap="gray", vmin=0, vmax=vmax0)
axes[1].set_title(f"Coronal x={x}")

im_sagittal = axes[2].imshow(vol[:, :, z], cmap="gray", vmin=0, vmax=vmax0)
axes[2].set_title(f"Sagittal z={z}")

for ax in axes:
    ax.set_aspect("equal")

fig.suptitle(f"{current_method} + {current_filter}")

ax_y = plt.axes([0.15, 0.23, 0.55, 0.03])
ax_x = plt.axes([0.15, 0.18, 0.55, 0.03])
ax_z = plt.axes([0.15, 0.13, 0.55, 0.03])
ax_c = plt.axes([0.15, 0.08, 0.55, 0.03])

s_y = Slider(ax_y, "Axial y", 0, ny - 1, valinit=y, valstep=1)
s_x = Slider(ax_x, "Coronal x", 0, nx - 1, valinit=x, valstep=1)
s_z = Slider(ax_z, "Sagittal z", 0, nz - 1, valinit=z, valstep=1)
s_c = Slider(ax_c, "Contrast", vmax0 / 100, vmax0 * 5, valinit=vmax0)

method_ax = plt.axes([0.81, 0.48, 0.16, 0.38])
method_radio = RadioButtons(
    method_ax,
    ("CGLS10", "CGLS20", "CGLS50", "CGLS100", "SIRT100", "SIRT200", "SIRT300"),
    active=4
)

filter_ax = plt.axes([0.81, 0.18, 0.16, 0.24])
filter_radio = RadioButtons(
    filter_ax,
    ("None", "Gaussian", "Median", "NLM", "TV"),
    active=2
)

def update_images():
    yy = int(s_y.val)
    xx = int(s_x.val)
    zz = int(s_z.val)
    vmax = s_c.val

    im_axial.set_data(vol[yy, :, :])
    im_coronal.set_data(vol[:, xx, :])
    im_sagittal.set_data(vol[:, :, zz])

    im_axial.set_clim(0, vmax)
    im_coronal.set_clim(0, vmax)
    im_sagittal.set_clim(0, vmax)

    axes[0].set_title(f"Axial y={yy}")
    axes[1].set_title(f"Coronal x={xx}")
    axes[2].set_title(f"Sagittal z={zz}")

    fig.suptitle(f"{current_method} + {current_filter}")
    fig.canvas.draw_idle()

def refresh_volume():
    global vol

    vol = prepare_volume(current_method, current_filter)

    vmax = np.percentile(vol, 99.5)
    if vmax <= 0:
        vmax = 1.0

    s_c.valmax = vmax * 5
    s_c.valmin = vmax / 100
    s_c.set_val(vmax)

    update_images()

def method_update(label):
    global current_method
    current_method = label
    refresh_volume()

def filter_update(label):
    global current_filter
    current_filter = label
    refresh_volume()

s_y.on_changed(lambda val: update_images())
s_x.on_changed(lambda val: update_images())
s_z.on_changed(lambda val: update_images())
s_c.on_changed(lambda val: update_images())

method_radio.on_clicked(method_update)
filter_radio.on_clicked(filter_update)

plt.show()
