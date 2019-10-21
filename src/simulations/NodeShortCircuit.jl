export NodeShortCircuit
using OrdinaryDiffEq: ODEProblem, Rodas4, set_u!,init, solve!, step!, reinit!, savevalues!, u_modified!
import DiffEqBase: solve

"""
```Julia
NodeShortCircuit(;node,var,f)
```
# Keyword Arguments
- `node`: number  of the node
- `R`: resistance of the shortcircuit
- `sc_timespan`: shortcircuit timespan
"""
struct NodeShortCircuit
    node
    R
    tspan_fault
end
NodeShortCircuit(;node,R,sc_timespan) = NodeShortCircuit(node,R,sc_timespan)

function (nsc::NodeShortCircuit)(powergrid)
    # Currently this assumes that the lines are PiModels...
    lines = copy(powergrid.lines)
    l_idx = findfirst(l -> (l.from == nsc.node || l.to == nsc.node) && l isa PiModelLine, lines)

    if l_idx == nothing
        @warn "Node needs to be connected to a PiModelLine to implement NodeShortCircuit"
        return nothing
    end

    if lines[l_idx].from == nsc.node
        lines[l_idx] = PiModelLine(;from=lines[l_idx].from, to=lines[l_idx].to, y = lines[l_idx].y, y_shunt_km = 1/nsc.R,  y_shunt_mk = lines[l_idx].y_shunt_mk)
    elseif lines[l_idx].to == nsc.node
        lines[l_idx] = PiModelLine(;from=lines[l_idx].from, to=lines[l_idx].to, y = lines[l_idx].y, y_shunt_km = lines[l_idx].y_shunt_km,  y_shunt_mk = 1/nsc.R)
    end
    PowerGrid(powergrid.nodes, lines)
end

"""
```Julia
simulate(nsc::NodeShortCircuit, powergrid, x1, timespan)
```
Simulates a [`NodeShortCircuit`](@ref)
"""
function simulateOld(nsc::NodeShortCircuit, powergrid, x1, timespan)
    sc_timespan = nsc.sc_timespan
    @assert timespan[1] < sc_timespan[1]
    @assert timespan[2] > sc_timespan[2]
    nsc_powergrid = nsc(powergrid)

    # Integrate to fault
    prob1 = ODEProblem(rhs(powergrid), x1, (timespan[1], sc_timespan[1]))
    sol1 = solve(prob1, Rodas4(autodiff=false))

    # Integrate the fault state
    x2 = find_valid_initial_condition(nsc_powergrid, sol1[end]) # Jump the state to be valid for the new system.
    prob2 = ODEProblem(rhs(nsc_powergrid), x2, sc_timespan)
    sol2 = solve(prob2, Rodas4(autodiff=false))

    # Integrate after fault
    x3 = find_valid_initial_condition(powergrid, sol2[end]) # Jump the state to be valid for the new system.
    prob3 = ODEProblem(rhs(powergrid), x3, (sc_timespan[2], timespan[2]))
    sol3 = solve(prob3, Rodas4(autodiff=false))

    sol1, sol2, sol3
end

function simulate(nsc::NodeShortCircuit, powergrid, x1, timespan)
    @assert first(timespan) <= nsc.tspan_fault[1] "fault cannot begin in the past"
    @assert nsc.tspan_fault[2] <= last(timespan) "fault cannot end in the future"
    nsc_powergrid = nsc(powergrid)

    problem = ODEProblem{true}(rhs(powergrid), x1, timespan)
    integrator = init(problem, Rodas4(autodiff=false))

    step!(integrator, nsc.tspan_fault[1], true)
    sol1 = integrator.sol

    # update integrator with error
    x2 = find_valid_initial_condition(nsc_powergrid, sol1[end]) # Jump the state to be valid for the new system.
    set_u!(integrator, x2)
    integrator.f = rhs(nsc_powergrid)
    u_modified!(integrator,true)

    step!(integrator, nsc.tspan_fault[2], true)
    sol2 = integrator.sol

    # update integrator, clear error
    integrator.f = rhs(powergrid)
    x3 = find_valid_initial_condition(powergrid, sol2[end])
    set_u!(integrator, x3)
    u_modified!(integrator,true)
    solve!(integrator)

    return PowerGridSolution(integrator.sol, powergrid)
end
