function plot_nodal_diagram(p, t, u, xg, yg, varargin)
%PLOT_NODAL_DIAGRAM  Show a PDE Modeler solution as a labelled grid of nodal values.
%
%   PDE Modeler solves on an irregular triangular mesh, so its answers sit
%   at mesh nodes you did not choose. Hand methods (finite difference /
%   control volume) use a regular grid of nodal points instead. This
%   function reads the PDE Modeler solution at the regular grid of points
%   YOU choose, draws them as a labelled node diagram, and prints the same
%   values as a table in the Command Window, so the two methods can be
%   compared node by node.
%
%   USAGE
%     plot_nodal_diagram(p, t, u, xg, yg)
%     plot_nodal_diagram(p, t, u, xg, yg, 'ColorByGroup', groupIdx)
%
%   Most users should run CALL_NODAL_DIAGRAM instead, which checks the
%   exported variables and only asks for xg and yg.
%
%   REQUIRED INPUTS
%     p    Mesh node coordinates, 2-by-N: row 1 = x, row 2 = y.
%          From PDE Modeler: Mesh > Export Mesh (exports p, e and t).
%
%     t    Mesh triangles, 4-by-M (or 3-by-M). Rows 1-3 are the node
%          numbers of each triangle's corners; row 4 (subdomain number)
%          is ignored. From the same Mesh > Export Mesh.
%
%     u    Solution at every mesh node: a vector with N values (one per
%          column of p). From PDE Modeler: Solve > Export Solution.
%          Time-dependent (parabolic/hyperbolic) solutions export one
%          column per time step; pass a single column, e.g. u(:, end)
%          for the last time.
%
%     xg   x-coordinates of your nodal points (at least 2 values, in
%          increasing order), in the same units as the geometry.
%          Example: 0:0.015:0.06
%
%     yg   y-coordinates of your nodal points (at least 2 values, in
%          increasing order). Example: 0:0.015:0.09
%
%          Every combination (xg(i), yg(j)) is one nodal point, so the
%          example above gives 5 x 7 = 35 nodal points.
%
%   OPTIONAL INPUT
%     'ColorByGroup', groupIdx
%          numel(yg)-by-numel(xg) matrix of positive whole numbers, one per
%          nodal point (row j <-> yg(j), column i <-> xg(i)). It only sets
%          the marker colour, e.g. 1 = fixed-temperature nodes,
%          2 = convective nodes, 3 = interior nodes. Five colours are
%          defined; group 6 reuses the colour of group 1, and so on.
%          If omitted, every nodal point is drawn in the same blue.
%
%   OUTPUT
%     A figure with:
%       - the real outline of the meshed domain (grey line);
%       - a filled marker and its value at every nodal point that lies
%         inside the domain;
%       - a hollow grey marker, with no value, at every nodal point that
%         lies outside it (for example inside a notch or a hole).
%     In the Command Window:
%       - the x and y range of the mesh (use these to check xg and yg);
%       - a table of x, y, value and inside (yes/no), top row first.
%     A warning is shown if any nodal point is outside the domain.
%
%   HOW EACH VALUE IS FOUND
%     1. Find the mesh triangle that contains the nodal point.
%     2. Interpolate u linearly between that triangle's three corners
%        (barycentric weights), which matches the linear triangular
%        elements of the exported mesh.
%     3. If no triangle contains the point, check whether it sits within
%        1e-6 (geometry units) of a mesh node. Corner and edge points can
%        be missed by the triangle search because of round-off; those take
%        that node's value directly.
%     4. Otherwise the point is outside the domain and gets no value.
%
%   REQUIREMENTS
%     Core MATLAB only (triangulation, pointLocation,
%     cartesianToBarycentric, freeBoundary). The PDE Toolbox is needed
%     only to build and solve the model in PDE Modeler.
%
%   See also CALL_NODAL_DIAGRAM.

    % =====================================================================
    % 0. Check the inputs, so a mistake gives a clear message rather than
    %    a wrong diagram. (These checks never change the result for valid
    %    inputs; they only stop invalid ones.)
    % =====================================================================
    if size(p, 1) ~= 2
        error('plot_nodal_diagram:badP', ...
            ['p must be 2-by-N (row 1 = x, row 2 = y), as exported by ' ...
             'Mesh > Export Mesh. The p given is %d-by-%d.'], size(p, 1), size(p, 2));
    end
    if size(t, 1) < 3
        error('plot_nodal_diagram:badT', ...
            ['t must have at least 3 rows (triangle corner node numbers), ' ...
             'as exported by Mesh > Export Mesh. The t given is %d-by-%d.'], ...
            size(t, 1), size(t, 2));
    end
    nNodes = size(p, 2);
    if ~isvector(u)
        error('plot_nodal_diagram:badU', ...
            ['u is %d-by-%d. This looks like a time-dependent solution with ' ...
             'one column per time step. Pass one column, e.g. u(:, end) ' ...
             'for the last time.'], size(u, 1), size(u, 2));
    end
    if numel(u) ~= nNodes
        error('plot_nodal_diagram:sizeMismatch', ...
            ['u has %d values but the mesh has %d nodes. Export the mesh ' ...
             'and the solution again from the SAME solved model ' ...
             '(re-meshing after solving changes the number of nodes).'], ...
            numel(u), nNodes);
    end
    if numel(xg) < 2 || numel(yg) < 2
        error('plot_nodal_diagram:badGrid', ...
            'xg and yg must each contain at least 2 values, e.g. xg = 0:0.015:0.06.');
    end

    % ---- optional 'ColorByGroup' argument ----
    groupIdx = [];
    if ~isempty(varargin)
        for k = 1:2:length(varargin)
            if strcmpi(varargin{k}, 'ColorByGroup')
                groupIdx = varargin{k+1};
            end
        end
    end
    if ~isempty(groupIdx) && ~isequal(size(groupIdx), [numel(yg), numel(xg)])
        error('plot_nodal_diagram:badGroup', ...
            ['ColorByGroup must be numel(yg)-by-numel(xg) = %d-by-%d ' ...
             '(one group number per nodal point). The matrix given is %d-by-%d.'], ...
            numel(yg), numel(xg), size(groupIdx, 1), size(groupIdx, 2));
    end

    u  = u(:);             % make u a column vector
    nx = length(xg);       % number of nodal points along x (columns)
    ny = length(yg);       % number of nodal points along y (rows)

    % =====================================================================
    % 1. Build a triangulation object from the exported mesh
    % =====================================================================
    % Rows 1-3 of t are node numbers (columns of p); row 4 is not needed.
    tri = t(1:3,:)';                     % M-by-3: one triangle per row
    TR  = triangulation(tri, p(1,:)', p(2,:)');

    % =====================================================================
    % 2. Find the value of u at every nodal point
    % =====================================================================
    % Xq, Yq are ny-by-nx: row j <-> yg(j), column i <-> xg(i).
    [Xq, Yq] = meshgrid(xg, yg);
    qpts = [Xq(:), Yq(:)];               % all nodal points as an (ny*nx)-by-2 list

    triIdx = pointLocation(TR, qpts);    % containing triangle; NaN if none
    Tgrid   = nan(ny, nx);               % interpolated value at each nodal point
    inside  = false(ny, nx);             % true if the point lies in the domain

    % Round-off tolerance for step 2b, in geometry units. Kept very small,
    % so it only catches points that are genuinely ON a mesh node; it does
    % not pull outside points into the domain.
    snapTol = 1e-6;

    % Xq(:), Tgrid(k) and inside(k) all use MATLAB's column-major order, so
    % list entry k and matrix element k refer to the same nodal point.
    for k = 1:numel(triIdx)
        if ~isnan(triIdx(k))
            % 2a. Inside a triangle: linear interpolation between its 3 corners
            vids = tri(triIdx(k), :);           % node numbers of the 3 corners
            bary = cartesianToBarycentric(TR, triIdx(k), qpts(k,:));
            Tgrid(k)  = bary * u(vids);         % weighted sum of corner values
            inside(k) = true;
        else
            % 2b. No triangle found: is the point sitting on a mesh node
            %     (e.g. a domain corner) that the search missed by round-off?
            d = sqrt((p(1,:) - qpts(k,1)).^2 + (p(2,:) - qpts(k,2)).^2);
            [dmin, idx] = min(d);
            if dmin <= snapTol
                Tgrid(k)  = u(idx);
                inside(k) = true;
            end
            % 2c. Otherwise: outside the domain, left as NaN / not inside.
        end
    end

    if any(~inside(:))
        warning(['%d of %d query points fell outside the meshed domain ' ...
                  '(e.g. inside a notch/hole) and were skipped.'], ...
                  sum(~inside(:)), numel(inside));
    end

    % Grid spacing, used only to place the value labels beside the markers.
    typicalSpacing = min([xg(2)-xg(1), yg(2)-yg(1)]);

    % =====================================================================
    % 3. Draw the node diagram
    % =====================================================================
    figure; hold on; axis equal;
    xlabel('x [m]'); ylabel('y [m]');
    title('Node Diagram: Nodal Values from PDE Toolbox Solution');

    % Outline of the actual meshed domain (not a bounding box)
    fb = freeBoundary(TR);
    for e = 1:size(fb,1)
        plot(p(1,fb(e,:)), p(2,fb(e,:)), 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
    end

    for jj = 1:ny
        for ii = 1:nx
            xq = xg(ii);
            yq = yg(jj);

            if ~inside(jj,ii)
                % Outside the domain: hollow grey marker, no value
                plot(xq, yq, 'o', 'MarkerSize', 8, ...
                     'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0.6 0.6 0.6]);
                continue
            end

            val = Tgrid(jj,ii);

            % Marker colour: one blue for all, or by user-supplied group
            if isempty(groupIdx)
                markerColor = [0.2 0.4 0.8];
            else
                g = groupIdx(jj,ii);
                palette = [0 0.45 0.85;   % group 1
                           0.85 0.2 0.2;  % group 2
                           0.2 0.7 0.3;   % group 3
                           0.9 0.6 0.1;   % group 4
                           0.5 0.3 0.7]; % group 5 (groups 6+ reuse these)
                markerColor = palette(mod(g-1, size(palette,1)) + 1, :);
            end

            plot(xq, yq, 'o', 'MarkerSize', 10, ...
                 'MarkerFaceColor', markerColor, 'MarkerEdgeColor', 'k');
            text(xq + 0.02*typicalSpacing, yq, sprintf('%.2f', val), ...
                 'FontSize', 8, 'VerticalAlignment', 'middle');
        end
    end

    hold off;
    grid on;

    % =====================================================================
    % 4. Print the mesh extent and the nodal table to the Command Window
    % =====================================================================
    % Compare these ranges with xg and yg if the diagram looks wrong.
    fprintf('x range: %.4f to %.4f\n', min(p(1,:)), max(p(1,:)));
    fprintf('y range: %.4f to %.4f\n', min(p(2,:)), max(p(2,:)));
    fprintf('\n%8s %8s %12s %8s\n', 'x', 'y', 'T', 'inside');
    for jj = ny:-1:1   % top row first, matching the diagram
        for ii = 1:nx
            if inside(jj,ii)
                fprintf('%8.4f %8.4f %12.3f %8s\n', xg(ii), yg(jj), Tgrid(jj,ii), 'yes');
            else
                fprintf('%8.4f %8.4f %12s %8s\n', xg(ii), yg(jj), '--', 'no');
            end
        end
    end
end
