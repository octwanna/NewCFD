subroutine calc_next_step_inp(q,w,Flux,Source,dt,dx,Vol,sonic,A)
   use prmtr
   implicit none
   integer i,j
   double precision,dimension(3,0:CellNum) :: q,w,Flux,Source,rhs,dq
   double precision,dimension(  0:CellNum) :: Vol,sonic,A
   double precision,dimension(  0:CellNum) :: NUMax,abar,factor
   double precision fact,v,H
   double precision,dimension(3) :: ds
   double precision,dimension(3,3) :: LUSGSVectorA,LUSGSVectorB,LUSGSVectorC
   double precision,dimension(3,3,0:CellNum) :: dfdq

   double precision dt,dx

   !!EULER SCHEME=========================={{{
   !!$omp parallel do
   !do i=1,CellNum-1
   !      !q(:,i)=q(:,i)+dt/Vol(i)*(Flux(:,i  )-Flux(:,i+1))+dt*Source(:,i)
   !enddo
   !!$omp end parallel do
   !!}}}

   !LUSGS SCHEME=========================={{{
   !RIGHT HAND SIDE====================
   !$omp parallel do
   do i=1,CellNum-1
         rhs(1:3,i)=Flux(1:3,i  )-Flux(1:3,i+1)
         rhs(2,i)=rhs(2,i)+Vol(i)*Source(2,i)
   enddo
   !$omp end parallel do

   !$omp parallel do
   do i=1,CellNum-1
         NUMax(i)=abs(w(2,i))+sonic(i)
         abar(i)=0.5d0*(A(i)+A(i+1))
         factor(i)=Vol(i)/dt+abar(i)*NUMax(i)
         rhs(1:3,i)=rhs(1:3,i)/factor(i)
   enddo
   !$omp end parallel do
   !point-implicit scheme==================
   !$omp parallel do
   do i=1,CellNum-1
      fact=(A(i+1)-A(i))/Vol(i)*(gamma-1d0)
      v=w(2,i)
      ds(1)= fact*0.5d0*v*v
      ds(2)=-fact*v
      ds(3)= fact
      
      LUSGSVectorA(1,1)=1d0
      LUSGSVectorA(1,2)=0d0
      LUSGSVectorA(1,3)=0d0
      LUSGSVectorA(2,1)=dt*ds(1)/(1d0-dt*ds(2))
      LUSGSVectorA(2,2)=1d0/(1d0-dt*ds(2))
      LUSGSVectorA(2,3)=dt*ds(3)/(1d0-dt*ds(2))
      LUSGSVectorA(3,1)=0d0
      LUSGSVectorA(3,2)=0d0
      LUSGSVectorA(3,3)=1d0
      
      dq(1:3,i)=MATMUL(LUSGSVectorA,rhs(1:3,i))
   enddo
   !$omp end parallel do
   !forward substitution==================
   !$omp parallel do
   do i=1,CellNum-1
      v=w(2,i)
      H=0.5d0*v**2+sonic(i)**2/(gamma-1d0)

      dfdq(1,1,i)=0d0
      dfdq(1,2,i)=1d0
      dfdq(1,3,i)=0d0
      dfdq(2,1,i)=0.5d0*(gamma-3d0)*v*v
      dfdq(2,2,i)=(3d0-gamma)*v
      dfdq(2,3,i)=gamma-1d0
      dfdq(3,1,i)=0.5d0*v*(-2d0*H+(gamma-1d0)*v*v)
      dfdq(3,2,i)=H-(gamma-1d0)*v*v
      dfdq(3,3,i)=gamma*v
   enddo
   !$omp end parallel do
   !$omp parallel do
   do i=2,CellNum-1
      LUSGSVectorB=0.5d0*dfdq(1:3,1:3,i-1)
      LUSGSVectorB(1,1)=LUSGSVectorB(1,1)+0.5*NUMax(i-1)
      LUSGSVectorB(2,2)=LUSGSVectorB(2,2)+0.5*NUMax(i-1)
      LUSGSVectorB(3,3)=LUSGSVectorB(3,3)+0.5*NUMax(i-1)

      fact=abar(i-1)/factor(i)
      dq(1:3,i)=dq(1:3,i)+fact*MATMUL(LUSGSVectorB,dq(1:3,i-1))
   enddo
   !$omp end parallel do
   !backward substitution==================
   !$omp parallel do
   do i=CellNum-2,1,-1
      LUSGSVectorC=0.5d0*dfdq(1:3,1:3,i+1)
      LUSGSVectorC(1,1)=LUSGSVectorC(1,1)-0.5*NUMax(i+1)
      LUSGSVectorC(2,2)=LUSGSVectorC(2,2)-0.5*NUMax(i+1)
      LUSGSVectorC(3,3)=LUSGSVectorC(3,3)-0.5*NUMax(i+1)

      fact=abar(i+1)/factor(i)
      dq(1:3,i)=dq(1:3,i)-fact*MATMUL(LUSGSVectorC,dq(1:3,i+1))
   enddo
   !$omp end parallel do

   !UPdata==================
   !$omp parallel do
   do i=1,CellNum-1
      q(1:3,i)=q(1:3,i)+dq(1:3,i)
   enddo
   !$omp end parallel do
   !}}}

end subroutine calc_next_step_inp
