c-----------------------------------------------------------------------
c x13r glue code. Not part of the Census Bureau source.
c-----------------------------------------------------------------------
c rgetarg replaces the getarg intrinsic in getxop.f. It asks the C
c wrapper for argument N, which R passed to x13_run().
c-----------------------------------------------------------------------
      SUBROUTINE rgetarg(N,Arg)
      IMPLICIT NONE
      INTEGER N,i,nchr
      CHARACTER*(*) Arg
      INTEGER buf(1024)
      nchr=min(len(Arg),1024)
      CALL x13rarg(N,buf,nchr)
      DO i=1,len(Arg)
       IF(i.le.nchr)THEN
        Arg(i:i)=char(buf(i))
       ELSE
        Arg(i:i)=' '
       END IF
      END DO
      RETURN
      END
