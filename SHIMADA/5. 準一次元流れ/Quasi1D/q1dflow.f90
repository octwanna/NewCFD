!****************************************************************************
!
!  PROGRAM: prog11   q1dflow.f90
!
! Quasi 1-D Euler Solver
! Roe's Scheme : Flux Difference Splliting Scheme for Euler Equations
!
!  first-order explicit time integration
!  higher-order space approximation
!  Limiting at most
!  Entropy Fix is done
!
!     phi=1.  :  Higher-Oder Space discritization
!     phi=0.  :  1st-Oder Space discritization
!	  kappa=-1    : full upwind 2nd order
!	  kappa=0.    : Fromm's 2nd order
!	  kappa=1./3. : 3rd order 
!	  kappa=1.	  : central 2nd order
!
! T.Shimada 01/1/25
!
!****************************************************************************
      program q1dflow
!	 ===== program 11 =====

      implicit real*8 (a-h,o-z)
      real*8 kappa
      parameter(n=101)
!
      dimension x(n),q(3,0:n),f(3,n),w_L(3,n),w_R(3,n), A(n), Vol(n), s2(n)
      dimension dw_b(3), dw_f(3), w_c(3)
      namelist /input/ CFL, maxiter, ipiter, phi, kappa, delta
      namelist /flow/ rL,uL,pL,tL,rR,uR,pR,tR, amol, gam
	  namelist /space/ xmin, xmax, xdia
	  namelist /boundary/ ibtype_in, ibtype_out
! 
! Definition of statement functions
!
      fnp(i)=gm*(q(3,i)-0.5*q(2,i)**2/q(1,i))
      fnu(i)=q(2,i)/q(1,i)
      fna(i)=sqrt(gam*fnp(i)/q(1,i))
	  fnt(i)=(q(3,i)/q(1,i)-0.5*fnu(i)**2)/cv
	  fnM(i)=fnu(i)/fna(i)
	  fnarea(xx)=1.+2.2*(xx-1.5)**2
	  fnia(xx)=xx+2.2/3.*(xx-1.5)**3


! Set Default values
!
      cfl=0.1
      kappa=1./3.
      phi=1. 
	  maxiter=100
	  ipiter=20

      rL=5.
      uL=0.
      pL=5.

      rR=1.
      uR=0.
      pR=1.

	  gam=1.4
	  amol=28.96

	  xmin=-1.
	  xmax=1.
	  xdia=0.
!
! types of inflow/outflow boundaries
!     ibtype_in =11  !  subsonic,  1st-order
      ibtype_in =12  !  subsonic,  2nd-order
!	  ibtype_in =20  !  supersonic
!
      ibtype_out=11  !  subsonic,  1st-order
!	  ibtype_out=12  !  subsonic,  2nd-order
!	  ibtype_out=21  !  supersonic, 1st-order
!	  ibtype_out=22  !  supersonic, 2nd-order
!

! read input data
!
      open(99,file='input11.txt',status='unknown')
      read(99,input)
      read(99,flow)
	  read(99,space)
	  read(99,boundary)
      close(99)

      write(6,input)
      write(6,flow)
	  write(6,space)
	  write(6,boundary)
      write(60,input)
      write(60,flow)
	  write(60,space)
	  write(60,boundary)

	  gasc=8314.511212/amol
	  gm=gam-1.
	  cv=gasc/gm

	  rL=pL/(gasc*tL)
	  rR=pR/(gasc*tR)
	  p0=pL
	  r0=rL
	  t0=p0/(gasc*r0)
	  a0=sqrt(gam*p0/r0)

!
! Cell locations
!
      dx=(xmax-xmin)/float(n-1)
      do i=1, n
         x(i)=xmin+dx*float(i-1)
		 A(i)=fnarea(x(i))
      end do
!
! Set Initial State
!
      do i=1, n-1
         dr=(rR-rL)/float(n-1)
		 du=(uR-uL)/float(n-1)
		 dp=(pR-pL)/float(n-1)
!
		 r$=rL+dr*float(i-1)
		 p$=pL+dp*float(i-1)
		 u$=uL+du*float(i-1)

		 q(1,i)=r$
		 q(2,i)=r$*u$
		 q(3,i)=p$/gm+0.5*r$*u$**2
		 x1=x(i)
		 x2=x(i+1)
		 vol(i)=fnia(x2)-fnia(x1)
      end do


	  time=0.
      ic=0
      ip=10
	  ipout=ipiter
      write(ip,'(e16.8)') (0.5*(x(i)+x(i+1)),i=1,n-1)
	  ip=ip+1
!	  write(ip,'(3e16.8)') (q(1,i)/r0,fnu(i)/a0,fnt(i)/t0,i=1,n-1)
	  write(ip,'(3e16.8)') (q(1,i),fnu(i),fnt(i),i=1,n-1)

	  open(51,file='residual.dat',status='unknown')
!
! Main Loop
!
      do while (ic.le.maxiter)

!Boudary condition
        if(ibtype_in.eq.11) then
		   u_in=fnu(1)
		   r_in=rL
		   p_in=pL
		else if(ibtype_in.eq.12) then
		   u_in=1.5*fnu(1)-0.5*fnu(2)
		   r_in=rL
		   p_in=pL
		else if(ibtype_in.eq.20) then
		   u_in=uL
		   r_in=rL
		   p_in=pL
		else
		   stop 'inflow boundary type does not match'
		end if
!
		if(ibtype_out.eq.11) then
		   u_out=fnu(n-1)
		   r_out=q(1,n-1)
		   p_out=pR
		else if(ibtype_out.eq.12) then
		   u_out=1.5*fnu(n-1)-0.5*fnu(n-2)
		   r_out=1.5*q(1,n-1)-0.5*q(1,n-2)
		   p_out=pR
		else if(ibtype_out.eq.21) then
		   u_out=fnu(n-1)
		   r_out=q(1,n-1)
		   p_out=fnp(n-1)
		else if(ibtype_out.eq.22) then
		   u_out=1.5*fnu(n-1)-0.5*fnu(n-2)
		   r_out=1.5*q(1,n-1)-0.5*q(1,n-2)
		   p_out=1.5*fnp(n-1)-0.5*fnp(n-2)
		else
			stop 'outflow boundary type does not match'
		end if
!
		q(1,0)=r_in
		q(2,0)=r_in*u_in
		q(3,0)=p_in/gm+0.5*r_in*u_in**2
!
		q(1,n)=r_out
		q(2,n)=r_out*u_out
		q(3,n)=p_out/gm+0.5*r_out*u_out**2
!
! Time step evaluation
         dtmin=1.e30
         do i=1,n-1
		    dti=(x(i+1)-x(i))/(abs(fnu(i))+fna(i))
            dtmin=min(dtmin,dti)
         end do
         dt=cfl*dtmin

         time=time+dt
         ic=ic+1
!
! evaluate left and right values at cell interfaces
!
         do i=1, n-1
            dw_b(1) = q(1,i  ) - q(1,i-1)
            dw_b(2) = fnu(i  ) - fnu(i-1)
            dw_b(3) = fnp(i  ) - fnp(i-1)
            dw_f(1) = q(1,i+1) - q(1,i  )
            dw_f(2) = fnu(i+1) - fnu(i  )
            dw_f(3) = fnp(i+1) - fnp(i  )
            w_c(1) = q(1,i)
            w_c(2) = fnu(i)
            w_c(3) = fnp(i)

            do j=1, 3
               del_w_r=0.5*((1.+kappa)*dw_b(j)+(1.-kappa)*dw_f(j))
               del_w_l=0.5*((1.-kappa)*dw_b(j)+(1.+kappa)*dw_f(j))

               del_w_lim=0.
               if(dw_b(j).ne.0.) then
                  theta=dw_f(j)/dw_b(j)
                  if(theta.gt.0.) then
                     dl=del_w_l*min(4.*theta/(1.-kappa+(1.+kappa)*theta),1.)
                     dr=del_w_r*min(4./(1.+kappa+(1.-kappa)*theta),1.)
                     del_w_lim=0.5*(sign(1.,dl)+sign(1.,dr))*min(abs(dl),abs(dr))
                  end if
               end if

               w_R(j,i  )=w_c(j)-0.5*phi*del_w_lim
               w_L(j,i+1)=w_c(j)+0.5*phi*del_w_lim
            end do
         end do
!
! boundary conditions
!
         w_R(1,n)=q(1,n)
         w_R(2,n)=fnu(n)
         w_R(3,n)=fnp(n)

         w_L(1,1)=q(1,0)
         w_L(2,1)=fnu(0)
         w_L(3,1)=fnp(0)
!
! Numerical Flux Evaluation  : Roe's Scheme
!
         do i=1, n
            HL=gam/gm*w_L(3,i)/w_L(1,i)+0.5*w_L(2,i)**2
            HR=gam/gm*w_R(3,i)/w_R(1,i)+0.5*w_R(2,i)**2

            rrl=sqrt(w_L(1,i))
            rrr=sqrt(w_R(1,i))
            fctL=rrl/(rrl+rrr)
            fctR=rrr/(rrl+rrr)

            uH=fctL*w_L(2,i) + fctR*w_R(2,i)
            HH=fctL*HL       + fctR*HR

            aH=sqrt(gm*(HH-0.5*uH**2))

            dq1=w_R(1,i)-w_L(1,i)
            dq2=w_R(1,i)*w_R(2,i)-w_L(1,i)*w_L(2,i)
            dq3=w_R(3,i)/gm+0.5*w_R(1,i)*w_R(2,i)**2 &
			   -w_L(3,i)/gm-0.5*w_L(1,i)*w_L(2,i)**2

            alpha1=(1.-0.5*gm*(uH/aH)**2)*dq1 &
                  +gm/aH**2*uH           *dq2 &
                  -gm/aH**2              *dq3
            alpha2=0.25*uH*(2.*aH+gm*uH) *dq1 &
                  +0.5*(-aH-gm*uH)       *dq2 &
                  +0.5*gm                *dq3
            alpha3=0.25*uH*(-2.*aH+gm*uH)*dq1 &
                  +0.5*(aH-gm*uH)        *dq2 &
                  +0.5*gm                *dq3

            aramda1=abs(    uH)
            aramda2=abs(-aH+uH)
            aramda3=abs( aH+uH)

! Entropy Fix Considered
			If(aramda2.lt.delta*aH) aramda2=(aramda2**2+delta**2*aH**2)/(2.*delta*aH)
			If(aramda3.lt.delta*aH) aramda3=(aramda3**2+delta**2*aH**2)/(2.*delta*aH)
!
            d1=alpha1                                *aramda1 &
			  +alpha2 /aH**2                         *aramda2 &
			  +alpha3 /aH**2                         *aramda3
            d2=alpha1 *uH                            *aramda1 &
			  +alpha2 *(-aH+uH)/aH**2                *aramda2 &
			  +alpha3 *( aH+uH)/aH**2                *aramda3
            d3=alpha1 *0.5*uH**2                     *aramda1 &
			  +alpha2 *(-uH/aH+0.5*(uH/aH)**2+1./gm) *aramda2 &
              +alpha3 *( uH/aH+0.5*(uH/aH)**2+1./gm) *aramda3

            f1L=w_L(1,i)*w_L(2,i)
            f2L=w_L(1,i)*w_L(2,i)**2+w_L(3,i)
            f3L=w_L(1,i)*w_L(2,i)*(w_L(3,i)*gam/gm/w_L(1,i)+0.5*w_L(2,i)**2)

            f1R=w_R(1,i)*w_R(2,i)
            f2R=w_R(1,i)*w_R(2,i)**2+w_R(3,i)
            f3R=w_R(1,i)*w_R(2,i)*(w_R(3,i)*gam/gm/w_R(1,i)+0.5*w_R(2,i)**2)

            f(1,i)=0.5*(f1L+f1R-d1) * A(i)
            f(2,i)=0.5*(f2L+f2R-d2) * A(i)
            f(3,i)=0.5*(f3L+f3R-d3) * A(i)
         end do
!
! Source term
!
         do i=1, n-1
			s2(i)=fnp(i)*(A(i+1)-A(i))/Vol(i)
		 end do
!
! Update field
!
		 residual=0.

         do i=1, n-1
            q(1,i)=q(1,i)-dt/Vol(i)*(f(1,i+1)-f(1,i))
            q(2,i)=q(2,i)-dt/Vol(i)*(f(2,i+1)-f(2,i)) + dt*s2(i)

			eng_old=q(3,i)
            q(3,i)=q(3,i)-dt/Vol(i)*(f(3,i+1)-f(3,i))
			residual=residual+(q(3,i)-eng_old)**2
         end do
		 residual=sqrt(residual)
!
! output
!
         write(51,'(i6,e16.8)') ic,log10(residual+1.e-20)

         if(ic.ge.ipout) then
            ipout=ipout+ipiter
            ip=ip+1
            write(6,*) 'Time=',time,'    residual=',log10(residual+1.e-20)
			
!		  write(ip,'(3e16.8)') (q(1,i)/r0,fnu(i)/a0,fnt(i)/t0,i=1,n-1)
		  write(ip,'(3e16.8)') (q(1,i),fnu(i),fnt(i),i=1,n-1)
         end if
      end do

		write(40) q
      stop
	end program q1dflow