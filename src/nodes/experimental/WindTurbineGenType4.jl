@doc doc"""
```Julia
WindTurbineGenType4(;I_n,k_PLL,f,f_s,T_m,k_P,τ_ω)
```

```
"""

@DynamicNode WindTurbineGenType4(D,K_PLL,Q_ref,C,J,P,ω_rref,u_dcref,K_Q,K_v,K_g1,K_g2,K_r1,K_r2) begin
    MassMatrix(m_u = false,m_int = [true,true,true,true,true,true,true,true,true,true])
end  begin
    @assert J>=0
    @assert K_g1>=0
    @assert K_g2>=0
    @assert K_r1 >=0
    @assert K_r2 >=0
    @assert ω_rref>=0
    @assert C>=0
    @assert K_PLL>=0
end [[θ_PLL,dθ_PLL],[ω,dω],[t_ω,dt_ω],[e_Idθ,de_Idθ],[e_IP,de_IP],[e_IV,de_IV],[u_dc,du_dc],[ω_r,dω_r],[i_q,di_q],[u_tref,du_tref]] begin
    function PI_control(e_I,e,K_P,K_I)
        @assert K_P>=0
        @assert K_I>=0
        de_I=e
        u = K_P*e+K_I*e_I
        return [de_I,u]
    end
    u_dq = u*exp(-1im*θ_PLL)
    v_d = real(u_dq)
    v_q = imag(u_dq)
    i_q = 0.


    de_Idθ,ω_PLL=PI_control(e_Idθ,v_q,K_PLL,K_PLL)#v_q*K_PLL
    println("ω_PLL",ω_PLL)

    dθ_PLL=ω_PLL
    τ_L=1
    T_H =5.5
    K_f=10
    f=50
    f_g = ω_PLL#*2π*50
    dω = 1/τ_L*(-ω + f_g)
    t_ω = -dω*K_f*T_H#-t_ω
    println("t_ω: ",t_ω)
    println("dω: ",dω)
    println("ω_PLL",ω_PLL)
    println("ω:",ω)

    #println("dθ_PLL: ", dθ_PLL)

    #ω = ω_r-1-dθ_PLL
    K_P=1
    dt = K_P*ω
    de_IV,i_d=PI_control(e_IV,(u_dcref-u_dc),K_g1,K_g2)
    i_dq = (i_d+1im*i_q)


    s_e = u_dq*conj(i_dq)# s=(v_d*i_d+v_q*i_q)+j(v_q*i_d-v_d*i_q)
    p_e = real(s_e)
    q_e = imag(s_e)

    # speed control:
    de_IP,t_e=PI_control(e_IP,(ω_rref-ω_r),K_r1,K_r2)
    t_e = t_e+t_ω
    p_in=t_e*ω_r
    t_m = P/ω_r+t_ω
    println("t_e",t_e)
    dω_r = 1/J*(t_m-t_e)#-D*ω_r)

    # DC voltage control:
    println("p_in",p_in)
    println("p_e",p_e)
    #println("q_e",q_e)
    du_dc = 1/C*(p_in-p_e)


    # reactive power control
    u_t=abs(u)#TODO: discuss!!!
    du_tref = K_Q*(Q_ref-q_e)
    di_q = K_v*(u_tref-u_t)

    #println("id: ",i_d)
    #println("i_q: ",i_q)
    #println("u_tref: ",u_tref)
    #println("u_t: ",u_t)
    #println("u_dc: ",u_dc)
    #println("u_dq: ",u_dq)
    println("ω_r: ",ω_r)
    #println("i: ",i)
    #println("u: ",u)
    #println("ω",ω)

    #du = i_dq*u_dq-u*conj(i)
    du = i - i_dq*exp(1im*θ_PLL)
end

export WindTurbineGenType4
