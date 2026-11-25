# From Control Volumes to PDE Modeler

*A practical handbook for translating hand-calculated heat-conduction problems into MATLAB's PDE Modeler.*

Author: Ugonna David Ugochukwu-Okeogu

> **Same physics, two dialects.** This guide walks through the translation step by step: problem setup, governing equation, boundary conditions, and the four modes of the PDE Specification dialog. The aim is for the software to stop feeling like a black box and start feeling like a very fast, very literal colleague.

## Contents

- [Introduction](#introduction)
- [1. The core conceptual shift](#1-the-core-conceptual-shift)
- [2. Translating the governing equation](#2-translating-the-governing-equation)
- [3. The PDE Specification menu: four modes, four physical stories](#3-the-pde-specification-menu-four-modes-four-physical-stories)
- [4. Boundary conditions: the real translation table](#4-boundary-conditions-the-real-translation-table)
- [5. Five habits worth internalizing](#5-five-habits-worth-internalizing)
- [6. Quick-reference cheat sheet](#6-quick-reference-cheat-sheet)
- [7. Getting your results back as nodal values](#7-getting-your-results-back-as-nodal-values)
- [Closing thought](#closing-thought)

## Introduction

Two people can solve the exact same heat-conduction problem and never once use the same vocabulary. One draws a grid, wraps a small imaginary box around each node, and balances how much heat flows in against how much flows out. The other opens PDE Modeler, states the physics as a single equation over the whole domain, and lets the software mesh it, discretize it and solve it. Both are doing the same physics. The order in which they do it, and the language each one uses to describe it, is completely different, and that difference is exactly where confusion tends to creep in.

This guide exists to close that gap. It follows the same order you already use when solving by hand (problem setup, governing equation, boundary conditions, solve) and at every stage shows exactly what changes when the same problem is handed to PDE Modeler, plus the small mental adjustments that make the translation click.

## 1. The core conceptual shift

By hand, you start from an energy balance on a finite volume around each node: you literally draw a small control volume, sum everything flowing in against everything flowing out across its faces, and turn that balance into one algebraic equation per node. Notice what that already implies: your very first step is discrete. You never write down the continuous governing equation at all; you go straight to a system of nodal equations.

PDE Modeler runs in the opposite direction. It starts from the continuous governing PDE (the equation your energy balance was secretly approximating all along) and only discretizes it for you, automatically, using finite elements, the moment you click **Solve**.

That reordering changes your job description. Instead of "build the system of equations", your task becomes "correctly state the continuous problem": the governing equation, the shape of the domain and the boundary conditions. Everything after that (meshing, discretizing, assembling the algebra, solving it) is handed to the software.

> **Worth flagging early.** Anything you were used to specifying per node (a fixed temperature at one particular node, say) now has to be specified per boundary segment instead. If the known condition sits in the middle of an edge rather than at its endpoint, split that edge first. It is a small workaround that pays for itself the first time you need it.

## 2. Translating the governing equation

Your steady-state conduction energy balance, once the control volume shrinks down to a point, collapses into one continuous statement:

$$\nabla \cdot (k \nabla T) + \dot{q} = 0$$

PDE Modeler's generic governing equation (the one you fill in under **PDE → PDE Specification** whenever **Elliptic** is selected) is written more abstractly:

$$-\nabla \cdot (c \nabla u) + a\,u = f$$

Line the two up term by term and the abstraction stops being abstract:

| Your symbol | Physical meaning | PDE Modeler symbol |
|---|---|---|
| $T$ | Temperature: the unknown you are solving for | $u$ |
| $k$ | Thermal conductivity | $c$ |
| $\dot{q}$ | Volumetric heat generation | $f$ |
| — | No term proportional to $T$ in pure conduction | $a = 0$ |

That last row is easy to skate past, but it is worth a beat. The $a$ term exists in the toolbox for problems that do have a term proportional to the unknown itself, such as radiation linearized against a reference temperature, or reaction-diffusion source terms. Standard conduction has no such term, so $a$ simply sits at zero.

So conceptually, every $k\,(T_\text{neighbor} - T_\text{node})/\Delta x^2$ term you used to write out by hand, node by node, is exactly what $c = k$ combined with automatic finite-element discretization reproduces for you. You never write a $\Delta x$-based difference again: you just tell the software what $k$ and $\dot{q}$ are, and it rebuilds the algebra from scratch, correctly, for whatever mesh it generates.

## 3. The PDE Specification menu: four modes, four physical stories

Open **PDE → PDE Specification** and you are handed exactly one choice to make first: **Elliptic**, **Parabolic**, **Hyperbolic** or **Eigenmodes**. That single radio button decides what physical question you are allowed to ask, and what extra information the dialog will demand from you next.

### 3.1 Elliptic: the steady-state story

No time, nothing changing, everything already balanced. This is the mode Section 2 was written for, and the one your hand-derived steady energy balance maps onto directly.

$$-\nabla \cdot (c \nabla u) + a\,u = f$$

The only inputs the dialog asks for are the three coefficients $c$, $a$ and $f$: no initial state, no time points. If your problem has already "settled down", this is home.

### 3.2 Parabolic: the "how do we get there" story

Add a single time derivative, and the equation stops describing a resting state and starts describing a journey toward one:

$$d\,\frac{\partial u}{\partial t} - \nabla \cdot (c \nabla u) + a\,u = f$$

Two things change. First, $d$ is a coefficient you have not needed until now. Physically it is the thermal mass $\rho c_p$ (density × specific heat): the storage term that was implicitly missing whenever you assumed steady state. Second, because the equation now depends on time, the dialog asks for two things elliptic mode never needed:

- an **initial condition** $u(x, y, 0)$, the equivalent of your "initial guess at every node" in a finite-difference time march;
- a **vector of solve times** (`tlist`) telling the solver which instants you actually want answers at.

Under the hood, the solver marches through those times using implicit time integration, which is unconditionally stable regardless of mesh size. Explicit finite differences are different: there your time step $\Delta t$ is capped by $\Delta x^2$ and the thermal diffusivity. Boundary conditions do not change shape here; they keep the same Dirichlet/Neumann structure as elliptic. Only the interior equation, and the extra inputs around it, are new.

### 3.3 Hyperbolic: the wave story

Swap that single time derivative for a second one, and the character of the equation changes completely:

$$d\,\frac{\partial^2 u}{\partial t^2} - \nabla \cdot (c \nabla u) + a\,u = f$$

A first-order-in-time term (parabolic) produces diffusive, smoothing-out behavior, which is exactly what heat conduction does. A second-order-in-time term (hyperbolic) produces oscillatory, wave-propagating behavior instead: think of a vibrating drumhead, not a cooling metal plate.

> **Worth being honest about.** Ordinary Fourier heat conduction is **parabolic, not hyperbolic**: heat genuinely diffuses rather than propagating as a wave. You will reach for hyperbolic mode for problems that are actually wave-like: structural vibration, acoustics, electromagnetic wave propagation, or the non-classical "second sound" models of heat transport seen in a few materials at very low temperature. If your problem is standard conduction, parabolic is almost always the correct box to tick.

Because the equation is now second-order in time, it needs two initial conditions instead of one: the initial state $u(x, y, 0)$ and the initial rate of change $\partial u/\partial t\,(x, y, 0)$, physically an "initial displacement" and an "initial velocity". Here $d$ behaves as an inertia or mass-density term rather than a thermal-storage one. Boundary conditions are, again, still just Dirichlet and Neumann underneath.

### 3.4 Eigenmodes: the natural-rhythm story

This mode drops time altogether: no initial condition, no `tlist`, no forcing term $f$. Instead it solves for a set of natural pairs:

$$-\nabla \cdot (c \nabla u) + a\,u = \lambda\, d\, u$$

These are the specific spatial patterns $u$ a system "wants" to settle into, and the specific values $\lambda$ at which it does so, when left alone with no external driving. Think of it as asking a drumhead which pitches it is capable of ringing at, absent anyone striking it in a particular way: the eigenvalues are the pitches, and the eigenfunctions are the shapes the membrane takes at each pitch.

In place of a forcing term or a time vector, the dialog asks for a range of eigenvalues to search within. Direct heat-conduction problems do not often call for this mode, but it is the natural tool for modal or vibration analysis on the same geometry. It is also genuinely useful for understanding the decay rates that a parabolic solution on that same geometry will eventually relax through.

### The four modes side by side

| Mode | Adds to the elliptic form | Extra inputs required | Physical question it answers |
|---|---|---|---|
| Elliptic | — (base form) | $c$, $a$, $f$ only | What is the final, settled state? |
| Parabolic | $d\,\partial u/\partial t$ | + initial condition, + `tlist` | How does the system evolve toward that state? |
| Hyperbolic | $d\,\partial^2 u/\partial t^2$ | + two initial conditions (state and rate), + `tlist` | How does a disturbance propagate or oscillate? |
| Eigenmodes | $-\lambda d u$ | + eigenvalue search range | What are the system's own natural patterns and rates? |

## 4. Boundary conditions: the real translation table

Whichever of the four modes you picked in Section 3, the boundary-condition menu underneath it never changes. PDE Modeler gives you exactly two ways to describe what happens at an edge, **Dirichlet** and **Generalized Neumann**, and every physical thing you might want to say about a boundary has to pass through one of those two doors.

**Dirichlet**: a known value, plain and simple:

$$h\,u = r$$

In the common case $h = 1$, this reduces to simply $u = r$: you are stating the value outright.

**Generalized Neumann**: anything involving a rate, gradient or flux:

$$\mathbf{n} \cdot (c \nabla u) + q\,u = g$$

This is where your hand-method instincts need the most adjusting, because the categories map differently than you would expect. Here are four physical situations, and where each one actually lands.

**Known / fixed temperature → Dirichlet.** If a real physical boundary is genuinely held at a known constant temperature, this is direct: $u = r$. It is rare in convection problems (you usually do not know a surface temperature; you are solving for it), but common for cases like "this edge is bolted to a heat sink held at 20 °C".

**Convection to an ambient fluid → Neumann, not Dirichlet.** This is the one people most often get wrong coming from hand methods. In your energy balance you write something like $h(T_\infty - T_\text{surface})$, and it feels like you are "assigning a temperature". You are not: $T_\text{surface}$ is unknown; only $T_\infty$ is known. The correct form is Neumann, with:

$$q = h, \qquad g = h\,T_\infty$$

This is exactly your convective energy-balance term rearranged into flux form. The solver works out what $T_\text{surface}$ has to be to satisfy that flux balance, arriving at the same answer Gauss–Seidel would have converged to by hand, just by a different road.

**Insulated or symmetry boundary → Neumann, zeroed out.** In your hand method, this shows up as literally dropping a term from the energy balance: there is no flux path through that face, so it just never appears. PDE Modeler does not let you omit anything. Every edge needs an explicit condition, so "no flux" has to be stated outright as zero-flux Neumann, never left blank.

$$q = 0, \qquad g = 0$$

**Prescribed heat flux → Neumann, flux value in $g$.** If a boundary carries a known flux (not a convective or proportional one; your $q''_B$, say), $q$ stays at zero and $g$ carries the flux magnitude directly, with its sign matched to the outward-normal convention.

$$q = 0, \qquad g = q''_B$$

## 5. Five habits worth internalizing

A few reflexes worth building now, since you will reuse them on every future geometry:

1. **Ask "value or flux?" before touching the dialog.** Dirichlet is for values you know (a fixed temperature). Neumann is for anything involving a rate, gradient, flux or convection, which, honestly, is most real thermal boundaries.
2. **Every edge needs a condition; there is no default or "ignore".** Unlike a hand method, where an insulated wall simply does not appear in your equations, here you must explicitly zero it out rather than trust an assumed default.
3. **The sign of $g$ and $q$ follows the outward normal,** which is tied to the edge traversal direction, not the physical direction of "hot" or "cold". Always sanity-check the resulting $-\nabla u$ plot against your physical intuition before trusting it.
4. **Symmetry and true insulation are mathematically identical but physically different.** Good practice: label them differently in your own notes even though the numbers you enter are the same, so you do not confuse yourself reading the geometry back later.
5. **The PDE Specification mode never changes the boundary-condition menu.** Elliptic, Parabolic, Hyperbolic and Eigenmodes all change the interior equation and its extra inputs; none of them adds a third boundary-condition type. It is still just Dirichlet and Neumann, every time.

## 6. Quick-reference cheat sheet

### Boundary conditions

| Physical situation | BC type | Parameters |
|---|---|---|
| Known / fixed temperature | Dirichlet | $h = 1$, $r = T_\text{fixed}$ (i.e. $u = r$) |
| Convection to ambient fluid | Neumann | $q = h$, $g = h\,T_\infty$ |
| Insulated / symmetry | Neumann | $q = 0$, $g = 0$ |
| Prescribed heat flux | Neumann | $q = 0$, $g = $ flux value |

### PDE Specification modes

| Mode | Governing equation |
|---|---|
| Elliptic | $-\nabla \cdot (c \nabla u) + a\,u = f$ |
| Parabolic | $d\,\partial u/\partial t - \nabla \cdot (c \nabla u) + a\,u = f$ |
| Hyperbolic | $d\,\partial^2 u/\partial t^2 - \nabla \cdot (c \nabla u) + a\,u = f$ |
| Eigenmodes | $-\nabla \cdot (c \nabla u) + a\,u = \lambda\,d\,u$ |

## 7. Getting your results back as nodal values

Once PDE Modeler has solved the problem, its answers sit at the nodes of an irregular triangular mesh, not at the regular nodal points of your hand calculation. To compare the two, use the nodal-diagram tool in this repository:

1. **Mesh → Export Mesh** (exports `p`, `e`, `t`) and **Solve → Export Solution** (exports `u`).
2. Set your nodal grid (`xg`, `yg`) in `call_nodal_diagram.m` and run it.

You get a labelled node diagram and a table of values at exactly the nodal points you chose. See the [README](../README.md) for the full walkthrough.

## Closing thought

Strip away the dialog boxes and menus, and nothing about the underlying physics has moved. You are still drawing a boundary around a region, still balancing what goes in against what comes out. PDE Modeler simply asks you to state the rules (the governing equation, the mode, the boundary types) rather than derive the algebra by hand, and it folds meshing, discretization and solving into one integrated step instead of three you would otherwise run separately.
