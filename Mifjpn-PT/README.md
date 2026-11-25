# Mifjpn-PT

Clean-room screen-space path-traced shader pack for **Minecraft Java Edition (1.20 - 26.x)** on **Iris + Sodium**.

## Key Features
- **Screen-Space Path-Traced GI & Variance-Guided Temporal Denoiser**: R2 quasirandom hemisphere sampling, Pixar branchless ONB, moment-clamped temporal accumulation, and depth/normal-aware upsampling.
- **Physically Grounded Direct Shading & LabPBR 1.3**: Height-correlated Smith-GGX specular BRDF, conductor F0 presets, parallax occlusion mapping (POM), and auto luma-gradient normals.
- **Spherical Atmosphere & Volumetric Media**: Chapman airmass Rayleigh/Mie/ozone sky scattering, 3D volumetric clouds, Nether soot/embers, and End nebula/mist sea.
- **Advected Multi-Band Ocean Optics**: 28-band Jacobian-advected wave spectrum, exact unpolarized dielectric Fresnel, Beer-Lambert absorption, and Hessian caustics.
- **Mod Compatibility**: Native G-buffer / depth integration for **Distant Horizons** and **Physics Mod Pro (Ocean v3)** displacement hooks.

## License
Distributed under the [MIT License](./LICENSE).
