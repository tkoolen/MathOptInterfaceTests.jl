using MathOptInterfaceUtilities # Defines getindex for VectorAffineFunction
const MOIU = MathOptInterfaceUtilities

# Continuous conic problems

function _lin1test(solver::Function, config::TestConfig, vecofvars::Bool)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver,
    #    MOI.ScalarAffineFunction{Float64},
    #    [
    #        (MOI.VectorOfVariables,MOI.Nonnegatives),
    #        (MOI.VectorAffineFunction{Float64},MOI.Nonnegatives),
    #        (MOI.VectorAffineFunction{Float64},MOI.Zeros)
    #    ]
    #)
    # linear conic problem
    # min -3x - 2y - 4z
    # st    x +  y +  z == 3
    #            y +  z == 2
    #       x>=0 y>=0 z>=0
    # Opt obj = -11, soln x = 1, y = 0, z = 2

    instance = solver()

    v = MOI.addvariables!(instance, 3)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 3

    vov = MOI.VectorOfVariables(v)
    if vecofvars
        vc = MOI.addconstraint!(instance, vov, MOI.Nonnegatives(3))
    else
        vc = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), MOI.Nonnegatives(3))
    end

    c = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1,1,1,2,2], [v;v[2];v[3]], ones(5), [-3.0,-2.0]), MOI.Zeros(2))
    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.Nonnegatives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Zeros}()) == 1
    loc = MOI.get(instance, MOI.ListOfConstraints())
    @test length(loc) == 2
    @test (vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.Nonnegatives) in loc
    @test (MOI.VectorAffineFunction{Float64},MOI.Zeros) in loc

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction(v, [-3.0, -2.0, -4.0], 0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ -11 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), v) ≈ [1, 0, 2] atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), vc) ≈ [1, 0, 2] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c) ≈ zeros(2) atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc))
            @test MOI.get(instance, MOI.ConstraintDual(), vc) ≈ [0, 2, 0] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c))
            @test MOI.get(instance, MOI.ConstraintDual(), c) ≈ [-3, -1] atol=atol rtol=rtol
        end
    end
end

lin1vtest(solver::Function, config::TestConfig) = _lin1test(solver, config, false)
lin1ftest(solver::Function, config::TestConfig) = _lin1test(solver, config, false)

function _lin2test(solver::Function, config::TestConfig, vecofvars::Bool)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64},
    #[
    #    (MOI.VectorAffineFunction{Float64},MOI.Zeros),
    #    (MOI.VectorOfVariables,MOI.Nonnegatives),
    #    (MOI.VectorOfVariables,MOI.Nonpositives)
    #])
    # mixed cones
    # min  3x + 2y - 4z + 0s
    # st    x           -  s  == -4    (i.e. x >= -4)
    #            y            == -3
    #       x      +  z       == 12
    #       x free
    #       y <= 0
    #       z >= 0
    #       s zero
    # Opt solution = -82
    # x = -4, y = -3, z = 16, s == 0


    instance = solver()

    x,y,z,s = MOI.addvariables!(instance, 4)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 4

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([x,y,z], [3.0, 2.0, -4.0], 0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)

    c = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1,1,2,3,3], [x,s,y,x,z], [1.0,-1.0,1.0,1.0,1.0], [4.0,3.0,-12.0]), MOI.Zeros(3))

    vov = MOI.VectorOfVariables([y])
    if vecofvars
        vc = MOI.addconstraint!(instance, vov, MOI.Nonpositives(1))
    else
        vc = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), MOI.Nonpositives(1))
    end
    if vecofvars
        # test fallback
        vz = MOI.addconstraint!(instance, [z], MOI.Nonnegatives(1))
    else
        vz = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1], [z], [1.], [0.]), MOI.Nonnegatives(1))
    end
    vov = MOI.VectorOfVariables([s])
    if vecofvars
        vs = MOI.addconstraint!(instance, vov, MOI.Zeros(1))
    else
        vs = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), MOI.Zeros(1))
    end

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Zeros}()) == 2 - vecofvars
    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.Nonpositives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.Nonnegatives}()) == 1

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ -82 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ -4 atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), y) ≈ -3 atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), z) ≈ 16 atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), s) ≈ 0 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c) ≈ zeros(3) atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), vc) ≈ [-3] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vz))
        @test MOI.get(instance, MOI.ConstraintPrimal(), vz) ≈ [16] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vs))
        @test MOI.get(instance, MOI.ConstraintPrimal(), vs) ≈ [0] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c))
            @test MOI.get(instance, MOI.ConstraintDual(), c) ≈ [7, 2, -4] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc))
            @test MOI.get(instance, MOI.ConstraintDual(), vc) ≈ [0] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vz))
            @test MOI.get(instance, MOI.ConstraintDual(), vz) ≈ [0] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vs))
            @test MOI.get(instance, MOI.ConstraintDual(), vs) ≈ [7] atol=atol rtol=rtol
        end
    end
end

lin2vtest(solver::Function, config::TestConfig) = _lin2test(solver, config, true)
lin2ftest(solver::Function, config::TestConfig) = _lin2test(solver, config, false)

function lin3test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.VectorAffineFunction{Float64},MOI.Nonpositives),(MOI.VectorAffineFunction{Float64},MOI.Nonnegatives)])
    # Problem LIN3 - Infeasible LP
    # min  0
    # s.t. x ≥ 1
    #      x ≤ -1
    # in conic form:
    # min 0
    # s.t. -1 + x ∈ R₊
    #       1 + x ∈ R₋

    instance = solver()

    x = MOI.addvariable!(instance)

    MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[x],[1.0],[-1.0]), MOI.Nonnegatives(1))
    MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[x],[1.0],[1.0]), MOI.Nonpositives(1))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Nonnegatives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Nonpositives}()) == 1

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        if config.infeas_certificates
            @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success
        else
            @test MOI.get(instance, MOI.TerminationStatus()) in [MOI.InfeasibleNoResult, MOI.InfeasibleOrUnbounded]
        end
        if MOI.canget(instance, MOI.PrimalStatus())
            @test MOI.get(instance, MOI.PrimalStatus()) == MOI.InfeasiblePoint
        end
        if config.duals && config.infeas_certificates
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.InfeasibilityCertificate
        end
        # TODO test dual feasibility and objective sign
    end
end

function lin4test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.VectorAffineFunction{Float64},MOI.Nonnegatives),(MOI.VectorOfVariables,MOI.Nonpositives)])
    # Problem LIN4 - Infeasible LP
    # min  0
    # s.t. x ≥ 1
    #      x ≤ 0
    # in conic form:
    # min 0
    # s.t. -1 + x ∈ R₊
    #           x ∈ R₋

    instance = solver()

    x = MOI.addvariable!(instance)

    MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[x],[1.0],[-1.0]), MOI.Nonnegatives(1))
    MOI.addconstraint!(instance, MOI.VectorOfVariables([x]), MOI.Nonpositives(1))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Nonnegatives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.Nonpositives}()) == 1

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        if config.infeas_certificates
            @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success
        else
            @test MOI.get(instance, MOI.TerminationStatus()) in [MOI.InfeasibleNoResult, MOI.InfeasibleOrUnbounded]
        end

        if MOI.canget(instance, MOI.PrimalStatus())
            @test MOI.get(instance, MOI.PrimalStatus()) == MOI.InfeasiblePoint
        end
        if config.duals && config.infeas_certificates
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.InfeasibilityCertificate
        end
        # TODO test dual feasibility and objective sign
    end
end

const lintests = Dict("lin1v" => lin1vtest,
                      "lin1f" => lin1ftest,
                      "lin2v" => lin2vtest,
                      "lin2f" => lin2ftest,
                      "lin3"  => lin3test,
                      "lin4"  => lin4test)

@moitestset lin

function _soc1test(solver::Function, config::TestConfig, vecofvars::Bool)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.VectorAffineFunction{Float64},MOI.Zeros),(MOI.VectorOfVariables,MOI.SecondOrderCone)])
    # Problem SOC1
    # max 0x + 1y + 1z
    #  st  x            == 1
    #      x >= ||(y,z)||

    instance = solver()

    x,y,z = MOI.addvariables!(instance, 3)

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([y,z],[1.0,1.0],0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)

    ceq = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[x],[1.0],[-1.0]), MOI.Zeros(1))
    vov = MOI.VectorOfVariables([x,y,z])
    if vecofvars
        csoc = MOI.addconstraint!(instance, vov, MOI.SecondOrderCone(3))
    else
        csoc = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), MOI.SecondOrderCone(3))
    end

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Zeros}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.SecondOrderCone}()) == 1
    loc = MOI.get(instance, MOI.ListOfConstraints())
    @test length(loc) == 2
    @test (MOI.VectorAffineFunction{Float64},MOI.Zeros) in loc
    @test (vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.SecondOrderCone) in loc

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ sqrt(2) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ 1 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), y) ≈ 1/sqrt(2) atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), z) ≈ 1/sqrt(2) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ceq))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ceq) ≈ [0.] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(csoc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), csoc) ≈ [1., 1/sqrt(2), 1/sqrt(2)] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ceq))
            @test MOI.get(instance, MOI.ConstraintDual(), ceq) ≈ [-sqrt(2)] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(csoc))
            @test MOI.get(instance, MOI.ConstraintDual(), csoc) ≈ [sqrt(2), -1.0, -1.0] atol=atol rtol=rtol
        end
    end
end

soc1vtest(solver::Function, config::TestConfig) = _soc1test(solver, config, true)
soc1ftest(solver::Function, config::TestConfig) = _soc1test(solver, config, false)

function _soc2test(solver::Function, config::TestConfig, nonneg::Bool)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.VectorAffineFunction{Float64},MOI.Zeros),(MOI.VectorAffineFunction{Float64},MOI.Nonnegatives),(MOI.VectorAffineFunction{Float64},MOI.SecondOrderCone)])
    # Problem SOC2
    # min  x
    # s.t. y ≥ 1/√2
    #      x² + y² ≤ 1
    # in conic form:
    # min  x
    # s.t.  -1/√2 + y ∈ R₊
    #        1 - t ∈ {0}
    #      (t,x,y) ∈ SOC₃

    instance = solver()

    x,y,t = MOI.addvariables!(instance, 3)

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([x],[1.0],0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)

    if nonneg
        cnon = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[y],[1.0],[-1/sqrt(2)]), MOI.Nonnegatives(1))
    else
        cnon = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[y],[-1.0],[1/sqrt(2)]), MOI.Nonpositives(1))
    end
    ceq = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[t],[-1.0],[1.0]), MOI.Zeros(1))
    csoc = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1,2,3],[t,x,y],ones(3),zeros(3)), MOI.SecondOrderCone(3))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},nonneg ? MOI.Nonnegatives : MOI.Nonpositives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Zeros}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.SecondOrderCone}()) == 1

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ -1/sqrt(2) atol=atol rtol=rtol

        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ -1/sqrt(2) atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), y) ≈ 1/sqrt(2) atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), t) ≈ 1 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cnon))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cnon) ≈ [0.0] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ceq))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ceq) ≈ [0.0] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(csoc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), csoc) ≈ [1., -1/sqrt(2), 1/sqrt(2)] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cnon))
            @test MOI.get(instance, MOI.ConstraintDual(), cnon) ≈ [nonneg ? 1.0 : -1.0] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ceq))
            @test MOI.get(instance, MOI.ConstraintDual(), ceq) ≈ [sqrt(2)] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(csoc))
            @test MOI.get(instance, MOI.ConstraintDual(), csoc) ≈ [sqrt(2), 1.0, -1.0] atol=atol rtol=rtol
        end
    end
end

soc2ntest(solver::Function, config::TestConfig) = _soc2test(solver, config, true)
soc2ptest(solver::Function, config::TestConfig) = _soc2test(solver, config, false)

function soc3test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.VectorAffineFunction{Float64},MOI.Nonnegatives),(MOI.VectorAffineFunction{Float64},MOI.Nonpositives),(MOI.VectorAffineFunction{Float64},MOI.SecondOrderCone)])
    # Problem SOC3 - Infeasible
    # min 0
    # s.t. y ≥ 2
    #      x ≤ 1
    #      |y| ≤ x
    # in conic form:
    # min 0
    # s.t. -2 + y ∈ R₊
    #      -1 + x ∈ R₋
    #       (x,y) ∈ SOC₂

    instance = solver()

    x,y = MOI.addvariables!(instance, 2)

    MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[y],[1.0],[-2.0]), MOI.Nonnegatives(1))
    MOI.addconstraint!(instance, MOI.VectorAffineFunction([1],[x],[1.0],[-1.0]), MOI.Nonpositives(1))
    MOI.addconstraint!(instance, MOI.VectorAffineFunction([1,2],[x,y],ones(2),zeros(2)), MOI.SecondOrderCone(2))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Nonnegatives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Nonpositives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.SecondOrderCone}()) == 1

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        if MOI.canget(instance, MOI.PrimalStatus())
            @test MOI.get(instance, MOI.PrimalStatus()) == MOI.InfeasiblePoint
        end
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.InfeasibilityCertificate
        end

        # TODO test dual feasibility and objective sign
    end
end

function soc4test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.ScalarAffineFunction{Float64},MOI.Zeros),(MOI.VectorOfVariables,MOI.SecondOrderCone)])
    # Problem SOC4
    # min 0x[1] - 2x[2] - 1x[3]
    #  st  x[1]                                == 1 (c1a)
    #              x[2]         - x[4]         == 0 (c1b)
    #                      x[3]         - x[5] == 0 (c1c)
    #      x[1] >= ||(x[4],x[5])||                  (c2)
    # in conic form:
    # min  c^Tx
    # s.t. Ax + b ∈ {0}₃
    #      (x[1],x[4],x[5]) ∈ SOC₃
    # Like SOCINT1 but with copies of variables and integrality relaxed
    # Tests out-of-order indices in cones

    b = [-1.0, 0.0, 0.0]
    A = [ 1.0  0.0  0.0  0.0  0.0
          0.0  1.0  0.0 -1.0  0.0
          0.0  0.0  1.0  0.0 -1.0]
    c = [ 0.0,-2.0,-1.0, 0.0, 0.0]

    instance = solver()

    x = MOI.addvariables!(instance, 5)

    A_cols = x
    A_rows = [1,2,3,2,3]
    A_vals = [1.0,1.0,1.0,-1.0,-1.0]

    c1 = MOI.addconstraint!(instance, MOI.VectorAffineFunction(A_rows,A_cols,A_vals,b), MOI.Zeros(3))
    c2 = MOI.addconstraint!(instance, MOI.VectorOfVariables([x[1],x[4],x[5]]), MOI.SecondOrderCone(3))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.Zeros}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.SecondOrderCone}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction(x,c,0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        x_primal = MOI.get(instance, MOI.VariablePrimal(), x)
        @test x_primal[1]^2 ≥ x_primal[4]^2 + x_primal[5]^2 - atol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c2))
            x_dual = MOI.get(instance, MOI.ConstraintDual(), c2)
            @test x_dual[1]^2 ≥ x_dual[2]^2 + x_dual[3]^2 - atol

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c1))
            c1_dual = MOI.get(instance, MOI.ConstraintDual(), c1)

            @test dot(c,x_primal) ≈ -dot(c1_dual,b) atol=atol rtol=rtol
            @test (c-A'c1_dual) ≈ [x_dual[1], 0, 0, x_dual[2], x_dual[3]] atol=atol rtol=rtol
        end
    end
end

const soctests = Dict("soc1v" => soc1vtest,
                      "soc1f" => soc1ftest,
                      "soc2n" => soc2ntest,
                      "soc2p" => soc2ptest,
                      "soc3"  => soc3test,
                      "soc4"  => soc4test)

@moitestset soc

function _rotatedsoc1test(solver::Function, config::TestConfig, abvars::Bool)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64},
    #    [(MOI.SingleVariable,MOI.EqualTo{Float64}),
    #     (MOI.VectorOfVariables,MOI.RotatedSecondOrderCone)])
    # Problem SOCRotated1v
    # min 0a + 0b - 1x - 1y
    #  st  a            == 1/2
    #  st  b            == 1
    #      2a*b >= x^2+y^2
    # Problem SOCRotated1f - Problem SOCRotated1v with a and b substituted
    # min          -y - z
    #  st [0.5] - [      ] SOCRotated
    #     [1.0] - [      ] SOCRotated
    #     [0.0] - [-y    ] SOCRotated
    #     [0.0] - [    -z] SOCRotated

    instance = solver()

    x = MOI.addvariables!(instance, 2)
    if abvars
        a = MOI.addvariable!(instance)
        b = MOI.addvariable!(instance)
        vc1 = MOI.addconstraint!(instance, MOI.SingleVariable(a), MOI.EqualTo(0.5))
        vc2 = MOI.addconstraint!(instance, MOI.SingleVariable(b), MOI.EqualTo(1.0))
        rsoc = MOI.addconstraint!(instance, MOI.VectorOfVariables([a; b; x]), MOI.RotatedSecondOrderCone(4))
    else
        a = 0.5
        b = 1.0
        rsoc = MOI.addconstraint!(instance, MOI.VectorAffineFunction([3, 4], x, [1., 1.], [a, b, 0., 0.]), MOI.RotatedSecondOrderCone(4))
    end

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.EqualTo{Float64}}()) == (abvars ? 2 : 0)
    @test MOI.get(instance, MOI.NumberOfConstraints{abvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64},MOI.RotatedSecondOrderCone}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction(x,ones(2),0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ sqrt(2.0) atol=atol rtol=rtol

        if abvars
            @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
            @test MOI.get(instance, MOI.VariablePrimal(), a) ≈ 0.5 atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
            @test MOI.get(instance, MOI.VariablePrimal(), b) ≈ 1.0 atol=atol rtol=rtol
        end
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ [1.0/sqrt(2.0), 1.0/sqrt(2.0)] atol=atol rtol=rtol

        if abvars
            @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vc1))
            @test MOI.get(instance, MOI.ConstraintPrimal(), vc1) ≈ 0.5
            @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vc2))
            @test MOI.get(instance, MOI.ConstraintPrimal(), vc2) ≈ 1.0
        end

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(rsoc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), rsoc) ≈ [0.5, 1.0, 1.0/sqrt(2.0), 1.0/sqrt(2.0)] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.DualStatus(1))
            @test MOI.get(instance, MOI.DualStatus(1)) == MOI.FeasiblePoint

            if abvars
                @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc1))
                @test MOI.get(instance, MOI.ConstraintDual(), vc1) ≈ -sqrt(2) atol=atol rtol=rtol
                @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc2))
                @test MOI.get(instance, MOI.ConstraintDual(), vc2) ≈ -1/sqrt(2) atol=atol rtol=rtol
            end

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(rsoc))
            @test MOI.get(instance, MOI.ConstraintDual(), rsoc) ≈ [sqrt(2), 1/sqrt(2), -1.0, -1.0] atol=atol rtol=rtol
        end
    end
end

rotatedsoc1vtest(solver::Function, config::TestConfig) = _rotatedsoc1test(solver, config, true)
rotatedsoc1ftest(solver::Function, config::TestConfig) = _rotatedsoc1test(solver, config, false)

function rotatedsoc2test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64},
    #    [(MOI.SingleVariable,MOI.EqualTo{Float64}),
    #     (MOI.SingleVariable,MOI.LessThan{Float64}),
    #     (MOI.SingleVariable,MOI.GreaterThan{Float64}),
    #     (MOI.VectorOfVariables,MOI.RotatedSecondOrderCone)])
    # Problem SOCRotated2 - Infeasible
    # min 0
    # s.t.
    #      x ≤ 1
    #      y = 1/2
    #      z ≥ 2
    #      z^2 ≤ 2x*y
    # in conic form:
    # min 0
    # s.t.
    #      -1 + x ∈ R₋
    #     1/2 - y ∈ {0}
    #      -2 + z ∈ R₊
    #       (x,y,z) ∈ SOCRotated
    b = [-2, -1, 1/2]
    c = [0.0,0.0,0.0]

    instance = solver()

    x = MOI.addvariables!(instance, 3)

    vc1 = MOI.addconstraint!(instance, MOI.SingleVariable(x[1]), MOI.LessThan(1.0))
    vc2 = MOI.addconstraint!(instance, MOI.SingleVariable(x[2]), MOI.EqualTo(0.5))
    vc3 = MOI.addconstraint!(instance, MOI.SingleVariable(x[3]), MOI.GreaterThan(2.0))

    rsoc = MOI.addconstraint!(instance, MOI.VectorOfVariables(x), MOI.RotatedSecondOrderCone(3))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.LessThan{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.EqualTo{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.GreaterThan{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.RotatedSecondOrderCone}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction(x,c,0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) in [MOI.Success, MOI.InfeasibleNoResult, MOI.InfeasibleOrUnbounded]

        if MOI.get(instance, MOI.TerminationStatus()) in [MOI.Success, MOI.InfeasibleOrUnbounded] && config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) in [MOI.InfeasibilityCertificate, MOI.NearlyInfeasibilityCertificate]

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc1))
            y1 = MOI.get(instance, MOI.ConstraintDual(), vc1)
            @test y1 < -atol # Should be strictly negative

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc2))
            y2 = MOI.get(instance, MOI.ConstraintDual(), vc2)

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc3))
            y3 = MOI.get(instance, MOI.ConstraintDual(), vc3)
            @test y3 > atol # Should be strictly positive

            y = [y1, y2, y3]

            vardual = MOI.get(instance, MOI.ConstraintDual(), rsoc)

            @test vardual ≈ -y atol=atol rtol=rtol
            @test 2*vardual[1]*vardual[2] ≥ vardual[3]^2 - atol
            @test dot(b,y) > atol
        end
    end
end

function rotatedsoc3test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    # Problem SOCRotated3
    # max v
    # s.t.
    #      x[1:5] ≥ 0
    #      0 ≤ u ≤ 5
    #      v
    #      t1 == 1
    #      t2 == 1
    # [t1/√2, t2/√2, x] in SOC7
    # [x1/√2, u/√2,  v] in SOC3

    instance = solver()

    x = MOI.addvariables!(instance, 5)
    u = MOI.addvariable!(instance)
    v = MOI.addvariable!(instance)
    t = MOI.addvariables!(instance, 2)

    ct1 = MOI.addconstraint!(instance, MOI.SingleVariable(t[1]), MOI.EqualTo(1.0))
    ct2 = MOI.addconstraint!(instance, MOI.SingleVariable(t[2]), MOI.EqualTo(1.0))
    cx  = MOI.addconstraint!(instance, MOI.VectorOfVariables(x), MOI.Nonnegatives(5))
    cu1 = MOI.addconstraint!(instance, MOI.SingleVariable(u), MOI.GreaterThan(0.0))
    cu2 = MOI.addconstraint!(instance, MOI.SingleVariable(u), MOI.LessThan(5.0))

    c1 = MOI.addconstraint!(instance, MOI.VectorAffineFunction(collect(1:7), [t; x], [1/√2; 1/√2; ones(5)], zeros(7)), MOI.RotatedSecondOrderCone(7))
    c2 = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1, 2, 3], [x[1], u, v], [1/√2; 1/√2; 1.0], zeros(3)), MOI.RotatedSecondOrderCone(3))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.EqualTo{Float64}}()) == 2
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.Nonnegatives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.GreaterThan{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.LessThan{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.SingleVariable,MOI.GreaterThan{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64},MOI.RotatedSecondOrderCone}()) == 2

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([v],[1.0],0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ √5 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @show MOI.get(instance, MOI.VariablePrimal(), x)
        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ [1, 0, 0, 0, 0] atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), u) ≈ 5 atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), v) ≈ √5 atol=atol rtol=rtol
        @test MOI.get(instance, MOI.VariablePrimal(), t) ≈ ones(2) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cx))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cx) ≈ [1, 0, 0, 0, 0] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cu1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cu1) ≈ 5 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cu2))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cu2) ≈ 5 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ct1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ct1) ≈ 1.0 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ct1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ct1) ≈ 1.0 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c1) ≈ [1/√2, 1/√2, 1.0, 0.0, 0.0, 0.0, 0.0] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c2))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c2) ≈ [1/√2, 5/√2, √5] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cx))
            @show MOI.get(instance, MOI.ConstraintDual(), cx)
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cu1))
            @test MOI.get(instance, MOI.ConstraintDual(), cu1) ≈ 0.0 atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cu2))
            @show MOI.get(instance, MOI.ConstraintDual(), cu2)
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ct1))
            @show MOI.get(instance, MOI.ConstraintDual(), ct1)
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ct1))
            @show MOI.get(instance, MOI.ConstraintDual(), ct1)

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c1))
            @show MOI.get(instance, MOI.ConstraintDual(), c1)
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c2))
            @show MOI.get(instance, MOI.ConstraintDual(), c2)
        end
    end
end


const rsoctests = Dict("rotatedsoc1v" => rotatedsoc1vtest,
                       "rotatedsoc1f" => rotatedsoc1ftest,
                       "rotatedsoc2"  => rotatedsoc2test)

@moitestset rsoc

function _geomean1test(solver::Function, config::TestConfig, vecofvars, n=3)
    atol = config.atol
    rtol = config.rtol
    # Problem GeoMean1
    # max (xyz)^(1/3)
    # s.t.
    #      x + y + z ≤ 3
    # in conic form:
    # max t
    # s.t.
    #   (t,x,y,z) ∈ GeometricMeanCone(4)
    #     x+y+z-3 ∈ LessThan(0.)
    # By the arithmetic-geometric mean inequality,
    # (xyz)^(1/3) ≤ (x+y+z)/3 = 1
    # Therefore xyz ≤ 1
    # This can be attained using x = y = z = 1 so it is optimal.

    instance = solver()

    t = MOI.addvariable!(instance)
    x = MOI.addvariables!(instance, n)

    vov = MOI.VectorOfVariables([t; x])
    if vecofvars
        gmc = MOI.addconstraint!(instance, vov, MOI.GeometricMeanCone(n+1))
    else
        gmc = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), MOI.GeometricMeanCone(n+1))
    end
    c = MOI.addconstraint!(instance, MOI.ScalarAffineFunction(x, ones(n), 0.), MOI.LessThan(Float64(n)))

    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64}, MOI.GeometricMeanCone}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([t], [1.], 0.))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ 1 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), t) ≈ 1 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ ones(n) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(gmc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), gmc) ≈ ones(n+1) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c) ≈ n atol=atol rtol=rtol

    #    if config.duals
    #        @test MOI.canget(instance, MOI.DualStatus())
    #        @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
    #
    #        @test MOI.canget(instance, MOI.ConstraintDual(), typeof(gmc))
    #        @show MOI.get(instance, MOI.ConstraintDual(), gmc)
    #
    #        @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c))
    #        @show MOI.get(instance, MOI.ConstraintDual(), c)
    #    end
    end
end

geomean1vtest(solver::Function, config::TestConfig) = _geomean1test(solver, config, true)
geomean1ftest(solver::Function, config::TestConfig) = _geomean1test(solver, config, false)

geomeantests = Dict("geomean1v" => geomean1vtest,
                    "geomean1f" => geomean1ftest)

@moitestset geomean

function _exp1test(solver::Function, config::TestConfig, vecofvars::Bool)
    atol = config.atol
    rtol = config.rtol
    # Problem EXP1 - ExpPrimal
    # min x + y + z
    #  st  y e^(x/y) <= z, y > 0 (i.e (x, y, z) are in the exponential primal cone)
    #      x == 1
    #      y == 2

    instance = solver()

    v = MOI.addvariables!(instance, 3)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 3

    vov = MOI.VectorOfVariables(v)
    vov = MOI.VectorOfVariables(v)
    if vecofvars
        vc = MOI.addconstraint!(instance, vov, MOI.ExponentialCone())
    else
        vc = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), MOI.ExponentialCone())
    end

    cx = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([v[1]], [1.], 0.), MOI.EqualTo(1.))
    cy = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([v[2]], [1.], 0.), MOI.EqualTo(2.))

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction(v, ones(3), 0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ 3 + 2exp(1/2) atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), v) ≈ [1., 2., 2exp(1/2)] atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(vc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), vc) ≈ [1., 2., 2exp(1/2)] atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cx))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cx) ≈ 1 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cy))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cy) ≈ 2 atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(vc))
            u, v, w = MOI.get(instance, MOI.ConstraintDual(), vc)
            @test u ≈ -exp(1/2) atol=atol rtol=rtol
            @test v ≈ -exp(1/2)/2 atol=atol rtol=rtol
            @test w ≈ 1 atol=atol rtol=rtol

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cx))
            @test MOI.get(instance, MOI.ConstraintDual(), cx) ≈ 1 + exp(1/2) atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cy))
            @test MOI.get(instance, MOI.ConstraintDual(), cy) ≈ 1 + exp(1/2)/2 atol=atol rtol=rtol
        end
    end
end

exp1vtest(solver::Function, config::TestConfig) = _exp1test(solver, config, true)
exp1ftest(solver::Function, config::TestConfig) = _exp1test(solver, config, false)

function exp2test(solver::Function, config::TestConfig)
    # Problem EXP2
    # A problem where ECOS was failing
    atol = config.atol
    rtol = config.rtol

    instance = solver()

    v = MOI.addvariables!(instance, 9)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 9

    ec1 = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1, 1, 3], [v[2], v[3], v[4]], ones(3), [0., 1., 0.]), MOI.ExponentialCone())
    ec2 = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1, 1, 3], [v[2], v[3], v[5]], [1., -1., 1.], [0., 1., 0.]), MOI.ExponentialCone())
    c1 = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([v[4], v[5], v[6]], [.5, .5, -1.], 0.), MOI.EqualTo(0.))
    c2 = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1, 2, 3, 1, 2, 3], [v[1], v[2], v[3], v[7], v[8], v[9]], [ 1.,  1.,  1., 0.3, 0.3, 0.3], zeros(3)), MOI.Nonnegatives(3))
    c3 = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1, 2, 3, 1, 2, 3], [v[1], v[2], v[3], v[7], v[8], v[9]], [-1., -1., -1., 0.3, 0.3, 0.3], zeros(3)), MOI.Nonnegatives(3))
    c4 = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([v[7], v[8], v[9]], ones(3), 0.), MOI.LessThan(1.))
    c5 = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([v[7]], [1.], 0.), MOI.EqualTo(0.))

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([v[6]], [1.], 0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ exp(-0.3) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), v) ≈ [0., -0.3, 0., exp(-0.3), exp(-0.3), exp(-0.3), 0., 1.0, 0.] atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ec1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ec1) ≈ [-0.3, 1.0, exp(-0.3)] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ec2))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ec2) ≈ [-0.3, 1.0, exp(-0.3)] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c1) ≈ 0. atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c2))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c2) ≈ zeros(3) atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c3))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c3) ≈ [0., 0.6, 0.] atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c4))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c4) ≈ 1. atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c5))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c5) ≈ 0. atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ec1))
            @test MOI.get(instance, MOI.ConstraintDual(), ec1) ≈ [-exp(-0.3)/2, -1.3exp(-0.3)/2, 0.5] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ec2))
            @test MOI.get(instance, MOI.ConstraintDual(), ec2) ≈ [-exp(-0.3)/2, -1.3exp(-0.3)/2, 0.5] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c1))
            @test MOI.get(instance, MOI.ConstraintDual(), c1) ≈ -1 atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c5))
            d5 = MOI.get(instance, MOI.ConstraintDual(), c5) # degree of freedom
            d23 = (exp(-0.3)*0.3 - d5) / 0.6 # dual constraint corresponding to v[7]
            @test d23 >= -atol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c2))
            @test MOI.get(instance, MOI.ConstraintDual(), c2) ≈ [d23, exp(-0.3), exp(-0.3)/2] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c3))
            @test MOI.get(instance, MOI.ConstraintDual(), c3) ≈ [d23, 0.0, exp(-0.3)/2] atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c4))
            @test MOI.get(instance, MOI.ConstraintDual(), c4) ≈ -exp(-0.3)*0.3 atol=atol rtol=rtol
        end
    end
end

function exp3test(solver::Function, config::TestConfig)
    # Problem EXP3
    # A problem where ECOS was failing
    atol = config.atol
    rtol = config.rtol

    instance = solver()

    x = MOI.addvariable!(instance)
    y = MOI.addvariable!(instance)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 2

    xc = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([x], [2.], 0.), MOI.LessThan(4.))
    yc = MOI.addconstraint!(instance, MOI.SingleVariable(y), MOI.LessThan(5.))
    ec = MOI.addconstraint!(instance, MOI.VectorAffineFunction([1, 3], [x, y], ones(2), [0., 1., 0.]), MOI.ExponentialCone())

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([x], [1.], 0.0))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ log(5) atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), x) ≈ log(5) atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), y) ≈ 5. atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(xc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), xc) ≈ 2log(5) atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(yc))
        @test MOI.get(instance, MOI.ConstraintPrimal(), yc) ≈ 5 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(ec))
        @test MOI.get(instance, MOI.ConstraintPrimal(), ec) ≈ [log(5), 1., 5.] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(xc))
            @test MOI.get(instance, MOI.ConstraintDual(), xc) ≈ 0. atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(yc))
            @test MOI.get(instance, MOI.ConstraintDual(), yc) ≈ -1/5 atol=atol rtol=rtol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(ec))
            @test MOI.get(instance, MOI.ConstraintDual(), ec) ≈ [-1., log(5)-1, 1/5] atol=atol rtol=rtol
        end
    end
end

exptests = Dict("exp1v" => exp1vtest,
                "exp1f" => exp1ftest,
                "exp2"  => exp2test,
                "exp3"  => exp3test)

@moitestset exp

function _sdp0test(solver::Function, vecofvars::Bool, sdpcone, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}), (MOI.VectorOfVariables, sdpcone)])
    # min X[1,1] + X[2,2]    max y
    #     X[2,1] = 1         [0   y/2     [ 1  0
    #                         y/2 0    <=   0  1]
    #     X >= 0              y free

    instance = solver()

    X = MOI.addvariables!(instance, 3)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 3

    vov = MOI.VectorOfVariables(X)
    if vecofvars
        cX = MOI.addconstraint!(instance, vov, sdpcone(2))
    else
        cX = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), sdpcone(2))
    end

    c = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([X[2]], [1.], 0.), MOI.EqualTo(1.))

    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64}, sdpcone}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([X[1], X[3]], ones(2), 0.))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ 2 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), X) ≈ [1, 1, 1] atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(cX))
        @test MOI.get(instance, MOI.ConstraintPrimal(), cX) ≈ [1, 1, 1] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c))
            @test MOI.get(instance, MOI.ConstraintDual(), c) ≈ 2 atol=atol rtol=rtol

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cX))
            @test MOI.get(instance, MOI.ConstraintDual(), cX) ≈ [1, -1, 1] atol=atol rtol=rtol
        end
    end
end


function _sdp1test(solver::Function, vecofvars::Bool, sdpcone, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}), (MOI.VectorOfVariables, sdpcone), (MOI.VectorOfVariables, MOI.SecondOrderCone)])
    # Problem SDP1 - sdo1 from MOSEK docs
    # From Mosek.jl/test/mathprogtestextra.jl, under license:
    #   Copyright (c) 2013 Ulf Worsoe, Mosek ApS
    #   Permission is hereby granted, free of charge, to any person obtaining a copy of this
    #   software and associated documentation files (the "Software"), to deal in the Software
    #   without restriction, including without limitation the rights to use, copy, modify, merge,
    #   publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
    #   to whom the Software is furnished to do so, subject to the following conditions:
    #   The above copyright notice and this permission notice shall be included in all copies or
    #   substantial portions of the Software.
    #
    #     | 2 1 0 |
    # min | 1 2 1 | . X + x1
    #     | 0 1 2 |
    #
    #
    # s.t. | 1 0 0 |
    #      | 0 1 0 | . X + x1 = 1
    #      | 0 0 1 |
    #
    #      | 1 1 1 |
    #      | 1 1 1 | . X + x2 + x3 = 1/2
    #      | 1 1 1 |
    #
    #      (x1,x2,x3) in C^3_q
    #      X in C_sdp

    instance = solver()

    X = MOI.addvariables!(instance, 6)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 6
    x = MOI.addvariables!(instance, 3)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 9

    vov = MOI.VectorOfVariables(X)
    if vecofvars
        cX = MOI.addconstraint!(instance, vov, sdpcone(3))
    else
        cX = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), sdpcone(3))
    end
    cx = MOI.addconstraint!(instance, MOI.VectorOfVariables(x), MOI.SecondOrderCone(3))

    c1 = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([X[1], X[3], X[6], x[1]], [1., 1, 1, 1], 0.), MOI.EqualTo(1.))
    c2 = MOI.addconstraint!(instance, MOI.ScalarAffineFunction([X; x[2]; x[3]], [1., 2, 1, 2, 2, 1, 1, 1], 0.), MOI.EqualTo(1/2))

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([X[1:3]; X[5:6]; x[1]], [2., 2, 2, 2, 2, 1], 0.))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MinSense)

    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64}, sdpcone}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}()) == 2
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorOfVariables, MOI.SecondOrderCone}()) == 1

    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.ObjectiveValue())
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ 0.705710509 atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        Xv = MOI.get(instance, MOI.VariablePrimal(), X)
        Xp = [Xv[1] Xv[2] Xv[4]
              Xv[2] Xv[3] Xv[5]
              Xv[4] Xv[5] Xv[6]]
        @test eigmin(Xp) > -atol
        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        xv = MOI.get(instance, MOI.VariablePrimal(), x)
        @test xv[2]^2 + xv[3]^2 - xv[1]^2 < atol

        @test MOI.get(instance, MOI.ConstraintPrimal(), cX) ≈ Xv atol=atol rtol=rtol
        @test MOI.get(instance, MOI.ConstraintPrimal(), cx) ≈ xv atol=atol rtol=rtol
        @test MOI.get(instance, MOI.ConstraintPrimal(), c1) ≈ Xv[1]+Xv[3]+Xv[6]+xv[1] atol=atol rtol=rtol
        @test MOI.get(instance, MOI.ConstraintPrimal(), c2) ≈ Xv[1]+2Xv[2]+Xv[3]+2Xv[4]+2Xv[5]+Xv[6]+xv[2]+xv[3] atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c1))
            y1 = MOI.get(instance, MOI.ConstraintDual(), c1)
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c2))
            y2 = MOI.get(instance, MOI.ConstraintDual(), c2)

            #     X11  X21  X22  X31  X32  X33  x1  x2  x3
            c = [   2,   2,   2,   0,   2,   2,  1,  0,  0]
            b = [1, 1/2]
            # Check primal objective
            comp_pobj = dot(c, [Xv; xv])
            # Check dual objective
            comp_dobj = dot([y1, y2], b)
            @test comp_pobj ≈ comp_dobj atol=atol rtol=rtol

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(cX))
            Xdv = MOI.get(instance, MOI.ConstraintDual(), cX)
            Xd = [Xdv[1] Xdv[2] Xdv[4];
                  Xdv[2] Xdv[3] Xdv[5];
                  Xdv[4] Xdv[5] Xdv[6]]

            C = [2 1 0;
                 1 2 1;
                 0 1 2]
            A1 = [1 0 0;
                  0 1 0;
                  0 0 1]
            A2 = [1 1 1;
                  1 1 1;
                  1 1 1]

            @test C ≈ y1 * A1 + y2 * A2 + Xd atol=atol rtol=rtol

            @test eigmin(Xd) > -atol
        end
    end
end

sdp0tvtest(solver::Function, config::TestConfig) = _sdp0test(solver, true, MOI.PositiveSemidefiniteConeTriangle, config)
sdp0tftest(solver::Function, config::TestConfig) = _sdp0test(solver, false, MOI.PositiveSemidefiniteConeTriangle, config)
sdp1tvtest(solver::Function, config::TestConfig) = _sdp1test(solver, true, MOI.PositiveSemidefiniteConeTriangle, config)
sdp1tftest(solver::Function, config::TestConfig) = _sdp1test(solver, false, MOI.PositiveSemidefiniteConeTriangle, config)

function sdp2test(solver::Function, config::TestConfig)
    atol = config.atol
    rtol = config.rtol
    #@test MOI.supportsproblem(solver, MOI.ScalarAffineFunction{Float64}, [(MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}), (MOI.VectorOfVariables, MOI.PositiveSemidefiniteConeTriangle)])
    # Caused getdual to fail on SCS and Mosek
    instance = solver()

    x = MOI.addvariables!(instance, 7)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 7

    c = [0.0,0.0,0.0,0.0,0.0,0.0,1.0]
    b = [10.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
    I =  [1,  2,   8,   9,           10,  11,  1,  3,   8,                 9,                  10,                 11,  1,  4,   8,  9,  10, 11, 1,  5,   8,    1,  6,   8,     9,             10,    11,  1,  7,  8,  9, 10,  11,    8, 10]
    J =  [1,  1,   1,   1,            1,   1,  2,  2,   2,                 2,                   2,                  2,  3,  3,   3,  3,  3,  3,  4,  4,   4,    5,  5,   5,     5,              5,     5,  6,  6,  6,  6,  6,   6,    7,  7]
    V = -[1.0,1.0,-0.45,0.45/sqrt(2),-0.45,0.0,1.0,1.0,-0.7681980515339464,0.225,-0.13180194846605373,0.0,1.0,1.0,-0.9,0.0,0.0,0.0,1.0,1.0,-0.225,1.0,1.0,-0.1125,0.1125/sqrt(2),-0.1125,0.0,1.0,1.0,0.0,0.0,-0.225,0.0,1.0,1.0]

    A = sparse(I, J, V, length(b), length(c))

    f = MOI.VectorAffineFunction(I, x[J], V, b)

    c1 = MOI.addconstraint!(instance, MOIU.eachscalar(f)[1], MOI.GreaterThan(0.0))
    c2 = MOI.addconstraint!(instance, MOIU.eachscalar(f)[2:7], MOI.Nonpositives(6))
    c3 = MOI.addconstraint!(instance, MOIU.eachscalar(f)[8:10], MOI.PositiveSemidefiniteConeTriangle(2))
    c4 = MOI.addconstraint!(instance, MOIU.eachscalar(f)[11], MOI.EqualTo(0.))

    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64}, MOI.Nonpositives}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([x[7]], [1.], 0.))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint
        if config.duals
            @test MOI.canget(instance, MOI.DualStatus())
            @test MOI.get(instance, MOI.DualStatus()) == MOI.FeasiblePoint
        end

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        xv = MOI.get(instance, MOI.VariablePrimal(), x)
        @test all(xv[1:6] .> -atol)

        con = A * xv + b

        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c1))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c1) ≈ con[1] atol=atol rtol=rtol
        @test MOI.get(instance, MOI.ConstraintPrimal(), c1) ≈ 0.0 atol=atol rtol=rtol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c2))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c2) ≈ con[2:7] atol=atol rtol=rtol
        @test all(MOI.get(instance, MOI.ConstraintPrimal(), c2) .< atol)
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c3))
        Xv = MOI.get(instance, MOI.ConstraintPrimal(), c3)
        @test Xv ≈ con[8:10] atol=atol rtol=rtol
        s2 = sqrt(2)
        Xm = [Xv[1]    Xv[2]/s2
              Xv[2]/s2 Xv[3]]
        @test eigmin(Xm) > -atol
        @test MOI.canget(instance, MOI.ConstraintPrimal(), typeof(c4))
        @test MOI.get(instance, MOI.ConstraintPrimal(), c4) ≈ con[11] atol=atol rtol=rtol
        @test MOI.get(instance, MOI.ConstraintPrimal(), c4) ≈ 0.0 atol=atol rtol=rtol

        if config.duals
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c1))
            y1 = MOI.get(instance, MOI.ConstraintDual(), c1)
            @test y1 > -atol
            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c2))
            y2 = MOI.get(instance, MOI.ConstraintDual(), c2)
            @test all(MOI.get(instance, MOI.ConstraintDual(), c2) .< atol)

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c3))
            y3 = MOI.get(instance, MOI.ConstraintDual(), c3)
            s2 = sqrt(2)
            Ym = [y3[1]    y3[2]/s2
                  y3[2]/s2 y3[3]]
            @test eigmin(Ym) > -atol

            @test MOI.canget(instance, MOI.ConstraintDual(), typeof(c4))
            y4 = MOI.get(instance, MOI.ConstraintDual(), c4)

            y = [y1; y2; y3; y4]
            @test dot(c, xv) ≈ dot(b, y) atol=atol rtol=rtol
            A[9,:] *= 2 # See duality note for PositiveSemidefiniteConeTriangle, 9 correspond to a off-diagonal entry
            @test A' * y ≈ -c atol=atol rtol=rtol
        end
    end
end

const sdptests = Dict("sdp0tv" => sdp0tvtest,
                      "sdp0tf" => sdp0tftest,
                      "sdp1tv" => sdp1tvtest,
                      "sdp1tf" => sdp1tftest,
                      "sdp2"   => sdp2test)

@moitestset sdp

function _det1test(solver::Function, config::TestConfig, vecofvars::Bool, detcone)
    atol = config.atol
    rtol = config.rtol
    square = detcone == MOI.LogDetConeSquare || detcone == MOI.RootDetConeSquare
    logdet = detcone == MOI.LogDetConeTriangle || detcone == MOI.LogDetConeSquare
    # We look for an ellipsoid x^T P x ≤ 1 contained in the square.
    # Let Q = inv(P) (x^T Q x ≤ 1 is its polar ellipsoid), we have
    # max t
    #     t <= log det Q (or t <= (det Q)^(1/n))
    #             Q22 ≤ 1
    #            _________
    #           |         |
    #           |         |
    # -Q11 ≥ -1 |    +    | Q11 ≤ 1
    #           |         |
    #           |_________|
    #            -Q22 ≥ -1

    instance = solver()

    t = MOI.addvariable!(instance)
    @test MOI.get(instance, MOI.NumberOfVariables()) == 1
    Q = MOI.addvariables!(instance, square ? 4 : 3)
    @test MOI.get(instance, MOI.NumberOfVariables()) == (square ? 5 : 4)

    vov = MOI.VectorOfVariables([t; Q])
    if vecofvars
        cX = MOI.addconstraint!(instance, vov, detcone(2))
    else
        cX = MOI.addconstraint!(instance, MOI.VectorAffineFunction{Float64}(vov), detcone(2))
    end

    c = MOI.addconstraint!(instance, MOI.VectorAffineFunction(collect(1:2), [Q[1], Q[end]], [-1., -1.], ones(2)), MOI.Nonnegatives(2))

    @test MOI.get(instance, MOI.NumberOfConstraints{vecofvars ? MOI.VectorOfVariables : MOI.VectorAffineFunction{Float64}, detcone}()) == 1
    @test MOI.get(instance, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64}, MOI.Nonnegatives}()) == 1

    MOI.set!(instance, MOI.ObjectiveFunction(), MOI.ScalarAffineFunction([t], ones(1), 0.))
    MOI.set!(instance, MOI.ObjectiveSense(), MOI.MaxSense)
    if config.solve
        MOI.optimize!(instance)

        @test MOI.canget(instance, MOI.TerminationStatus())
        @test MOI.get(instance, MOI.TerminationStatus()) == MOI.Success

        @test MOI.canget(instance, MOI.PrimalStatus())
        @test MOI.get(instance, MOI.PrimalStatus()) == MOI.FeasiblePoint

        @test MOI.canget(instance, MOI.ObjectiveValue())
        expectedobjval = logdet ? 0. : 1.
        @test MOI.get(instance, MOI.ObjectiveValue()) ≈ expectedobjval atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        @test MOI.get(instance, MOI.VariablePrimal(), t) ≈ expectedobjval atol=atol rtol=rtol

        @test MOI.canget(instance, MOI.VariablePrimal(), MOI.VariableIndex)
        Qv = MOI.get(instance, MOI.VariablePrimal(), Q)
        @test Qv[1] ≈ 1. atol=atol rtol=rtol
        @test Qv[2] ≈ 0. atol=atol rtol=rtol
        if square
            @test Qv[3] ≈ 0. atol=atol rtol=rtol
        end
        @test Qv[end] ≈ 1. atol=atol rtol=rtol
    end
end

logdet1tvtest(solver::Function, config::TestConfig) = _det1test(solver, config, true, MOI.LogDetConeTriangle)
logdet1tftest(solver::Function, config::TestConfig) = _det1test(solver, config, false, MOI.LogDetConeTriangle)

const logdettests = Dict("logdet1tv" => logdet1tvtest,
                         "logdet1tf" => logdet1tftest)

@moitestset logdet

rootdet1tvtest(solver::Function, config::TestConfig) = _det1test(solver, config, true, MOI.RootDetConeTriangle)
rootdet1tftest(solver::Function, config::TestConfig) = _det1test(solver, config, false, MOI.RootDetConeTriangle)

const rootdettests = Dict("rootdet1tv" => rootdet1tvtest,
                          "rootdet1tf" => rootdet1tftest)

@moitestset rootdet

const contconictests = Dict("lin" => lintest,
                            "soc" => soctest,
                            "rsoc" => rsoctest,
                            "geomean" => geomeantest,
                            "exp" => exptest,
                            "sdp" => sdptest,
                            "logdet" => logdettest,
                            "rootdet" => rootdettest)

@moitestset contconic true
