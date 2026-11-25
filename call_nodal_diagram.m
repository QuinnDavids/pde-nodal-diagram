%CALL_NODAL_DIAGRAM  Draw the nodal-point diagram for a PDE Modeler solution.
%
%   STEP 1  In PDE Modeler, solve your model as usual.
%   STEP 2  Mesh  > Export Mesh      -> click OK  (puts p, e, t in the workspace)
%   STEP 3  Solve > Export Solution  -> click OK  (puts u in the workspace)
%           Keep the default names p, e, t and u.
%   STEP 4  Set your nodal grid in the YOUR INPUTS block below.
%   STEP 5  Run this script.
%
%   If the diagram looks wrong, compare your grid with the "x range" and
%   "y range" printed in the Command Window. They show the extent of the
%   mesh, in the same units you drew the geometry in.
%
%   See README.md for a full walkthrough.

% ---- Check that the exported variables are in the workspace ----
if ~exist('p', 'var') || ~exist('t', 'var') || ~exist('u', 'var')
    error(['p, t and/or u were not found in the workspace. In PDE Modeler, ' ...
           'use Mesh > Export Mesh and Solve > Export Solution first, ' ...
           'keeping the default names p, e, t and u.']);
end

% ========================== YOUR INPUTS ==========================
% Nodal grid, written as  start : spacing : end  in your geometry's units.
% Use the same nodes as your hand (finite-difference) calculation.
%
% Example below: a 0.06 m wide x 0.09 m tall plate with 0.015 m spacing
%   -> 5 nodal columns (x) and 7 nodal rows (y) = 35 nodal points.
xg = 0:0.015:0.06;     % x-coordinates of the nodal points
yg = 0:0.015:0.09;     % y-coordinates of the nodal points

% Time-dependent (parabolic/hyperbolic) models only: u has one column per
% time step. Remove the % on the next line to use the last time step.
% u = u(:, end);
% =================================================================

plot_nodal_diagram(p, t, u, xg, yg)

% Optional: colour nodal points by type. groupIdx must be
% numel(yg)-by-numel(xg) (one number per nodal point), e.g.
%   groupIdx = 3 * ones(numel(yg), numel(xg));   % 3 = interior
%   groupIdx([1 end], :) = 1;                    % bottom and top rows
%   groupIdx(:, [1 end]) = 2;                    % left and right columns
%   plot_nodal_diagram(p, t, u, xg, yg, 'ColorByGroup', groupIdx)
