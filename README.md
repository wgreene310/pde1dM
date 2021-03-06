# pde1dM
1D Partial Differential Equation Solver for MATLAB and Octave

`pde1dM` solves systems of partial differential equations (PDE) in a single
spatial variable and time. 
The input is mostly compatible with the MATLAB function `pdepe`. 
Many `pdepe` examples will work with `pde1dM` with only small changes. 

The main enhancement of `pde1dM` compared with `pdepe` is that 
`pde1dM` allows any number of ordinary differential equations (ODE) to be coupled to the system of PDE. 
One use of these ODE, for example, is to allow more complex boundary conditions at the two ends of the PDE domain. 

Two capabilities of `pdepe` are not currently supported by `pde1dM`.
When the PDE is defined in
a cylindrical or spherical coordinate system and the left end of the domain 
starts at zero, `pdepe` uses special approximation functions to account
for the singularity at this point; `pde1dM` does not. Also, `pdepe` supports
an event detection capability; `pde1dM` currently does not support events.

Several examples and basic documentation are included.
An excellent introduction to solving PDE with the `pdepe` function is
Professor Howard's note,
[Partial Differential Equations in MATLAB 7.0](http://www.math.tamu.edu/~phoward/m442/pdemat.pdf). 


## Installation ##
This code repository can be cloned (or a ZIP file downloaded) to any local directory.
This directory should be added to the MATLAB or Octave directory path using the `addpath`
function or the corresponding GUI command.
