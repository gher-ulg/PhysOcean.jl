# Collections of tools for physical oceanography

# Authors:
# Aida Alvera Azcarate
# Alexander Barth


module PhysOcean

using Compat
using Compat: CartesianIndices

using Dates
using Statistics


# temperature in Kelvin of 0 degree Celsius
const TK = 273.15

# angularspeed of earth with respect to fixed star
const OMEGA = 7.2921150E-5

function nansum(x)
    return sum(x[.!isnan.(x)])
end

function nansum(x,dim)
    m = isnan.(x)
    x2 = copy(x)
    x2[m] .= 0
    return sum(x2,dims = dim)
end

function nanmean(x)
    return mean(x[.!isnan.(x)])
end

function nanmean(x,dim)
    m = isnan.(x)
    x2 = copy(x)
    x2[m] .= 0

    return sum(x2,dims = dim) ./ sum(.!m,dims = dim)
end


"""
    datetime_matlab(datenum)

Return DateTime from matlab's and octave's datenum
"""
function datetime_matlab(datenum)
    # even if datenum is Int32, the computations must be done with Int64 to
    # prevent overflow
    return DateTime(1970,1,1) + Dates.Millisecond(round(Int64,(datenum-Int64(719529)) * 24*60*60*1000))
end


"""
    temperature68(T)

Convert temperature `T` from ITS-90 scale to the IPTS-68 scale following Saunders, 1990.

Saunders, P.M. 1990, The International Temperature Scale of 1990, ITS-90. No.10, p.10.
https://web.archive.org/web/20170304194831/http://webapp1.dlib.indiana.edu/virtual_disk_library/index.cgi/4955867/FID474/wocedocs/newsltr/news10/news10.pdf
"""
temperature68(T) = 1.00024 * T

"""
density of pure water at the temperature `T` (degree Celsius, ITS-90)
"""
function density_reference_pure_water(T)

    t = temperature68(T)

    # page 21, equation 14 of
    # http://web.archive.org/web/20170103000527/http://unesdoc.unesco.org/images/0005/000598/059832eb.pdf

    a0 = 999.842594 # why [-28.263737]
    a1 = 6.793952e-2
    a2 = -9.095290e-3
    a3 = 1.001685e-4
    a4 = -1.120083e-6
    a5 = 6.536332e-9

    ρ_w = a0 + (a1 + (a2 + (a3 + (a4 + a5 * t) * t) * t) * t) * t
    return ρ_w
end

function density0(S,T)
    t = temperature68(T)
    # page 21, equation (13) of
    # http://web.archive.org/web/20170103000527/http://unesdoc.unesco.org/images/0005/000598/059832eb.pdf

    b0 = 8.24493e-1
    b1 = -4.0899e-3
    b2 = 7.6438e-5
    b3 = -8.2467e-7
    b4 = 5.3875e-9
    c0 = -5.72466e-3
    c1 = 1.0227e-4
    c2 = -1.6546e-6
    d0 = 4.8314e-4

    ρ = density_reference_pure_water(T) + ((b0 + (b1 + (b2 + (b3 + b4 * t) * t) * t) * t) + (c0 + (c1 + c2 * t) * t) * sqrt(S) + d0 * S) * S;
    return ρ
end


"""
    density(S,T,p)

Compute the density of sea-water (kg/m³) at the salinity `S` (psu, PSS-78), temperature `T` (degree Celsius, ITS-90) and pressure `p` (decibar) using the UNESCO 1983 polynomial.

Fofonoff, N.P.; Millard, R.C. (1983). Algorithms for computation of fundamental properties of seawater. UNESCO Technical Papers in Marine Science, No. 44. UNESCO: Paris. 53 pp.
http://web.archive.org/web/20170103000527/http://unesdoc.unesco.org/images/0005/000598/059832eb.pdf
"""
function density(S,T,p)
    ρ = density0(S,T)

    if (p == 0)
        return ρ
    end

    K = secant_bulk_modulus(S,T,p)
    # convert decibars to bars
    p = p/10
    return ρ / (1 - p/K)
end


"""
    secant_bulk_modulus(S,T,p)

Compute the secant bulk modulus of sea-water (bars) at the salinity `S` (psu, PSS-78), temperature `T` (degree Celsius, ITS-90) and pressure `p` (decibar) using the UNESCO polynomial 1983.

Fofonoff, N.P.; Millard, R.C. (1983). Algorithms for computation of fundamental properties of seawater. UNESCO Technical Papers in Marine Science, No. 44. UNESCO: Paris. 53 pp.
http://web.archive.org/web/20170103000527/http://unesdoc.unesco.org/images/0005/000598/059832eb.pdf
"""
function secant_bulk_modulus(S,T,p)
    # convert decibars to bars
    p = p/10

    t = temperature68(T)

    # page 18, equation (19)
    e0 = +19652.21 # [-1930.06]
    e1 = +148.4206
    e2 = -2.327105
    e3 = +1.360477E-2
    e4 = -5.155288E-5
    Kw = e0 + (e1  + (e2 + (e3  + e4 * t) * t) * t) * t

    # page 18, equation (16)
    # probably typo f3 vs f2
    f0 = +54.6746;    g0 = +7.944E-2
    f1 = -0.603459;   g1 = +1.6483E-2
    f2 = +1.09987E-2; g2 = -5.3009E-4
    f3 = -6.1670E-5

    K0 = Kw + ((f0 + (f1 + (f2  + f3 * t) * t) * t) + (g0 + (g1 + g2 * t) * t) * sqrt(S)) * S

    if (p == 0)
        return K0
    end

    # page 19
    h0 = +3.239908 # [-0.1194975]
    h1 = +1.43713E-3
    h2 = +1.16092E-4
    h3 = -5.77905E-7
    Aw = h0 + (h1 + (h2 + h3 * t) * t) * t


    k0 = +8.50935E-5 # [+ 3.47718E-5]
    k1 = -6.12293E-6
    k2 = +5.2787E-8
    Bw = k0 + (k1 + k2 * t) * t

    # page 18, equation (17)
    i0 = +2.2838E-3; j0 = +1.91075E-4
    i1 = -1.0981E-5
    i2 = -1.6078E-6
    A = Aw + ((i0 + (i1 + i2 * t) * t) + j0 * sqrt(S)) * S

    # page 18, equation (18)
    m0 = -9.9348E-7
    m1 = +2.0816E-8
    m2 = +9.1697E-10
    B = Bw + (m0 + (m1 + m2 * t) * t) * S

    K = K0 + (A + B * p) * p

    return K
end



"""
    freezing_temperature(S)

Compute the freezing temperature (in degree Celsius) of sea-water based on the salinity `S` (psu).
"""
freezing_temperature(S) = (-0.0575 + 1.710523e-3 * sqrt(S) - 2.154996e-4 * S) * S


function _adiabatic_temperature_gradient_t68(S,T,P)
    ΔS = S - 35.

    ATG = ((((-2.1687e-16*T + 1.8676e-14)*T - 4.6206e-13)*P
            + ((2.7759e-12 * T - 1.1351e-10) * ΔS +
               ((-5.4481e-14*T + 8.733E-12)*T
                -6.7795e-10)*T + 1.8741e-8))*P
           +(-4.2393e-8 * T + 1.8932e-6) * ΔS
           +((6.6228e-10 * T - 6.836e-8)*T + 8.5258e-6)*T + 3.5803e-5)
    return ATG
end

"""
    adiabatic_temperature_gradient(S,T,P)

Compute the adiabatic temperature gradient (degree C/decibar)
of a water mass with the salinity `S` (psu, PSS-78) ) and
temperature `T` (degree C, ITS-90)) at the pressure `P` (db)
using the UNESCO polynomial 1983, page 44.

"""
function adiabatic_temperature_gradient(S,T,P)
    # convert to T68
    T68 = 1.00024 * T
    _adiabatic_temperature_gradient_t68(S,T68,P)
end
export adiabatic_temperature_gradient

"""
    potential_temperature(S,T,P,PR)

Potential temperature (degree C, ITS-90) as per UNESCO 1983 report of a water
mass with the salinity `S` (psu, PSS-78) and temperature `T` (degree C, ITS-90) at the pressure `P` (db)
relative to the reference pressure `PR` (db).
"""
function potential_temperature(S,T,P,PR)
    T68 = 1.00024 * T

    # 4th order Runge-Kutta
    ΔP = PR - P
    Δθ₁ = ΔP * _adiabatic_temperature_gradient_t68(S,T68,P)
    θ₁ = T68 + Δθ₁ / 2

    Δθ₂ = ΔP * _adiabatic_temperature_gradient_t68(S,θ₁,P + ΔP/2)
    q₁ = Δθ₁
    θ₂ = θ₁ + (1 - 1/sqrt(2)) * (Δθ₂ - q₁)

    Δθ₃ = ΔP * _adiabatic_temperature_gradient_t68(S,θ₂,P + ΔP/2)
    q₂ = (2 - sqrt(2)) * Δθ₂ + (-2 + 3/sqrt(2)) * q₁
    θ₃ = θ₂ + (1 + 1/sqrt(2)) * (Δθ₃ - q₂)

    Δθ₄ = ΔP * _adiabatic_temperature_gradient_t68(S,θ₃,P + ΔP)
    q₃ = (2 + sqrt(2)) * Δθ₃ + (-2 - 3/sqrt(2)) * q₂
    θ₄ = θ₃ + (Δθ₄ - 2q₃)/6

    return θ₄ / 1.00024
end

export potential_temperature

"""
    potential_density(S,T,P,PR)
Potential density (kg/m^3) of a water mass with the salinity `S`
(psu (PSS-78) ) and temperature `T` (degree C (ITS-90)) at the pressure `P` (db)
relative to the reference pressure `PR` (db).
"""
function potential_density(S,T,P,PR)
    θ = potential_temperature(S,T,P,PR)
    return density(S,θ,PR)
end
export potential_density

"""
    latentflux(Ts,Ta,r,w,pa)

Compute the latent heat flux (W/m²) using
the sea surface temperature `Ts` (degree Celsius),
the air temperature `Ta` (degree Celsius),
the relative humidity `r` (0 ≤ r ≤ 1, pressure ratio, not percentage),
the wind speed `w` (m/s)
and the air pressure (hPa).
"""
function latentflux(Ts,Ta,r,w,pa)


    Da = 1.5e-3;
    rhoa = 1.3; # kg m-3
    Lh = 2.5e6; # J
    epsilon = 0.622;

    esta = vaporpressure(Ta);
    ests = vaporpressure(Ts);

    qqa = r * esta * epsilon / pa;
    qqs = ests * epsilon / pa;


    Qe = Da * rhoa * abs(w) * (qqs-qqa) * Lh;

    return Qe
end

"""
    longwaveflux(Ts,Ta,e,tcc)

Compute the long wave heat flux (W/m²) using
the sea surface temperature `Ts` (degree Celsius),
the air temperature `Ta` (degree Celsius),
the wate vapour pressure `e` (hPa) and the total cloud coverage `ttc` (0 ≤ tcc ≤ 1).
"""
function longwaveflux(Ts,Ta,e,tcc)
    epsilon = 0.98;
    sigma = 5.67e-8;
    lambda = 0.69;

    # degree C to degree K
    Ts = Ts + TK
    Ta = Ta + TK

    Qb = epsilon * sigma  * Ts^4 * (0.39-0.05*sqrt(e))*(1-lambda*tcc^2)+4 * epsilon * sigma * Ts^3 *(Ts-Ta)

    return Qb
end

"""
    sensibleflux(Ts,Ta,w)

Compute the sensible heat flux (W/m²) using
the wind speed `w` (m/s),
the sea surface temperature `Ts` (degree Celsius),
the air temperature `Ta` (degree Celsius).
"""
function sensibleflux(Ts,Ta,w)
    Sta = 1.45e-3;
    ca = 1000;
    rhoa = 1.3;

    Qc = Sta * ca * rhoa * w * (Ts-Ta);

    return Qc
end

"""
    solarflux(Q,al)

Compute the solar heat flux (W/m²)
"""
function solarflux(Q,al)
    Qs = Q*(1-al)
    return Qs
end

"""
    vaporpressure(T)

Compute vapour pressure of water at the temperature `T` (degree Celsius) in hPa using Tetens equations.
The temperature must be postive.

Monteith, J.L., and Unsworth, M.H. 2008. Principles of Environmental Physics. Third Ed. AP, Amsterdam. http://store.elsevier.com/Principles-of-Environmental-Physics/John-Monteith/isbn-9780080924793
"""
function vaporpressure(T)
    # Monteith and Unsworth (2008), https://en.wikipedia.org/wiki/Tetens_equation
    e = 6.1078 * exp((17.27 * T)./(T + 237.3));
    return e
end


"""
    gausswin(N, α = 2.5)

Return a Gaussian window with `N` points with a standard deviation of
(N-1)/(2 α).
"""
function gausswin(N, α = 2.5)
    sigma = (N-1)/(2 * α)
    return [exp(- n^2 / (2*sigma^2)) for n = -(N-1)/2:(N-1)/2]
end

"""
    gaussfilter(x,N)

Filter the vector `x` with a `N`-point Gaussian window.
"""
function gaussfilter(x,N)
    b = gausswin(N);
    c = b/sum(b);
    imax = size(x,1);
    xf = zeros(imax)
    s=1;

    for i=1:imax
        xf[i] = sum(x[s:s+N-1] .* c);

        s = s+1;
        if s>=size(x,1)-N
            s=size(x,1)-N;
        end
    end

    return xf
end

"""
    coriolisfrequency(latitude)

Provides coriolisfrequency et given latidudes in DEGREES from -90 Southpole to +90 Northpole
"""
function coriolisfrequency(latitude)


    return 2*OMEGA*sin(pi/180*latitude)
end

"""
    earthgravity(latitude)

Provides gravity in m/s2 at ocean surface at given latidudes in DEGREES from -90 Southpole to +90 Northpole
"""
function earthgravity(latitude)

    latrad=pi/180*latitude
    return 9.780327*(1.0026454-0.0026512*
	         cos(2*latrad)+0.0000058*(cos(2*latrad))^2
	)
end



# """
#     meof(masks,vars; nsv = 20)
# Compute `nsv` multivariate EOFs. `masks` and `vars` are tuples.
# """
# function meof(masks,vars; nsv = 20)
#     sv = divand.statevector(masks)


#     X = divand.packens(sv,vars);

#     Xm = mean(X,2);
#     Xp = X .- Xm;
#     #@show mean(Xp,2)

#     S = svds(Xp; nsv = nsv);
#     eofs = divand.unpackens(sv,S[1][:U]);

#     m = divand.unpack(sv,Xm[:,1]);

#     totvar = sum(abs2,Xp)

#     # relative variance in percent
#     relvar = 100 * S[1][:S].^2 / totvar

#     return (m,eofs,relvar,totvar)
# end

function addprefix!(prefix,obsids)
    if prefix == ""
        return
    end

    for i in 1:length(obsids)
        obsids[i] = prefix * obsids[i]
    end
end


include("integraterhoprime.jl")
include("stericheight.jl")
include("deepestpoint.jl")
include("floodfill!.jl")
include("addlowtoheighdimension.jl")
include("geostrophy.jl")
include("streamfunctionvolumeflux.jl")

export nanmean, nansum, gausswin, vaporpressure, solarflux, sensibleflux, gaussfilter, longwaveflux, latentflux, datetime_matlab, freezing_temperature, density, secant_bulk_modulus, coriolisfrequency, earthgravity, integraterhoprime, stericheight, deepestpoint, floodfill!, addlowtoheighdimension, geostrophy, streamfunctionvolumeflux

include("castaway.jl")
export loadcastaway

include("CMEMS.jl")
export CMEMS

include("WorldOceanDatabase.jl")
export WorldOceanDatabase

include("ARGO.jl")
export ARGO


end
