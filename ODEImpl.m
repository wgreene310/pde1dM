%  
%   This library is free software; you can redistribute it and/or
%   modify it under the terms of the GNU General Public License
%   as published by the Free Software Foundation; either version 3
%   of the License, or (at your option) any later version.
%  
%   This library is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%   General Public License for more details.
%  
%   You should have received a copy of the GNU General Public License
%   along with this library; if not, visit
%   http://www.gnu.org/licenses/gpl.html or write to the Free Software
%   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.
% 
% Copyright (C) 2020-2021 William H. Greene

classdef ODEImpl
  
  %% Encapsulate the representation of additional ODE appended to FE model
  
  properties
    numODEVariables, numODEEquations;
  end
  
  methods
    
    function obj = ODEImpl(xmesh, odeFunc, odeICFunc, odeMesh, ...
        t0, u2, up2, f2, testFunctionDOFMap)
      if nargin < 9
        testFunctionDOFMap = [];
      end
      obj.diagnosticPrint=0;
      obj.lagMultAlg=3;
      obj.odeFunc = odeFunc;
      obj.odeICFunc = odeICFunc;
      obj.odeMesh = odeMesh;
      obj.meshMapper = PDEMeshMapper(xmesh, odeMesh);
      obj.y0Ode = odeICFunc();
      obj.numODEVariables = length(obj.y0Ode);
      v0Dot=zeros(obj.numODEVariables,1);
      f=obj.calcODEResidual(t0, u2, up2, f2, obj.y0Ode, v0Dot);
      nOde = size(f,1);
      obj.numODEEquations = nOde;
      %obj.numODELagMult = obj.numODEEquations-obj.numODEVariables;
      numFEMDofs = length(u2(:));
      obj.vRange = numFEMDofs+1:numFEMDofs+obj.numODEVariables;
      obj.eRange = numFEMDofs+1:numFEMDofs+nOde;
      obj.lRange = numFEMDofs+obj.numODEVariables+1:numFEMDofs+nOde;
      if obj.lagMultAlg
        % for now we allow fewer vars to be initialized than the
        % number of equations
        numExtraVars=nOde-obj.numODEVariables;
        v0 = [obj.y0Ode; zeros(numExtraVars,1)];
        v0Dot = zeros(nOde,1);
        [dfdv,dfdvDot]=obj.calcDOdeDv(t0, u2, up2, f2, v0, v0Dot);
        if obj.lagMultAlg==1
          obj.lagMultEqns=~any(dfdv|dfdvDot, 2);
        elseif obj.lagMultAlg==2 || obj.lagMultAlg==3
          varUsed=zeros(nOde,1);
          obj.lagMultEqns=true(nOde,1);
          % check each eqn for ode variables starting at diagonal
          for i=1:nOde
            for j=1:nOde
              ii = mod((i+j-2),nOde)+1;
              if (dfdv(i,ii) || dfdvDot(i,ii)) && ~varUsed(ii)
                obj.lagMultEqns(i) = false;
                varUsed(i)=1;
                break;
              end
            end
          end
        elseif obj.lagMultAlg==4
          dFdu=self.calcDOdeDu(t0, u2, up2, f2, v, v0Dot);
          obj.lagMultEqns=any(dFdu,2);
        end
        if obj.diagnosticPrint
          prtMat(dfdv, 'dfdv');
          prtMat(dfdvDot, 'dfdvDot');
          prtShortVec(obj.lagMultEqns, 'lagMultEqns');
          %obj.lagMultEqns=abs(diag(dfdv))<eps & abs(diag(dfdvDot))<eps;
          fprintf('numODELagMult=%d, %d\n', obj.numODELagMult, ...
            sum(obj.lagMultEqns));
        end
        obj.numODELagMult = sum(obj.lagMultEqns);
      else
        obj.numODELagMult = obj.numODEEquations-obj.numODEVariables;
      end
      
      if isempty(testFunctionDOFMap)
        obj.testFunctionIndex=[];
      else
        [numFEMDof, numFEMNodes]=size(u2);
        if numFEMDof ~= length(testFunctionDOFMap)
          error('pde1d:testFunctionDOFMapSize', ...
            'Length of testFunctionDOFMap must equal the number of PDE');
        end
        ii = repmat((0:numFEMNodes-1)*numFEMDof, numFEMDof, 1);
        tfi = repmat(testFunctionDOFMap(:), 1, numFEMNodes) + ii;
        obj.testFunctionIndex = tfi(:);
      end
    end
    
    function [R,Rdot]=updateResiduals(self, time, u, up, F, RFem, RdotFem)
      v=u.ode;
      vDot=up.ode;
      u2=u.fem2;
      up2=up.fem2;
      f2=F.fem2;
      f=self.calcODEResidual(time, u2, up2, f2, v, vDot);
      fdot=zeros(self.numODEEquations,1);
      if(self.numODELagMult)
        [dFdu,dFduDot]=self.calcDOdeDu(time, u2, up2, f2, v, vDot);
        dFdv=self.calcDOdeDv(time, u2, up2, f2, v, vDot);
        if self.lagMultAlg
          L=v(self.lagMultEqns);
          Rtmp = u.new(dFdu(self.lagMultEqns,:)'*L);
          r2=Rtmp.fem2;
          r2(:,1)=0; r2(:,end)=0; % zero BC terms
          Rdottmp = u.new(dFduDot(self.lagMultEqns,:)'*L);
          rd2=Rdottmp.fem2;
          rd2(:,1)=0; rd2(:,end)=0; % zero BC terms
          dm = self.testFunctionIndex;
          if isempty(dm)
            RFem = RFem + r2(:);
            RdotFem = RdotFem + rd2(:);
          else
            RFem(dm) = RFem(dm) + r2(:);
            RdotFem(dm) = RdotFem(dm) + rd2(:);
          end
          if self.lagMultAlg==2
            f = f + dFdv(self.lagMultEqns,:)'*L;
          end
        else
          L=self.getLFromSysVec(u.all);
          % add constraint contribution
          RFem = RFem + dFdu(self.numODEVariables+1:end,:)'*L;
          f = f + dFdv(self.numODEVariables+1:end,:)'*L;
        end
      end
      R=[RFem(:);f(:)];
      Rdot=[RdotFem; fdot(:)];
    end
    
    function f=calcODEResidual(self, time, u2, up2, f2, v, vDot)
      mm = self.meshMapper;
      uOde=mm.mapFunction(u2);
      upOde=mm.mapFunction(up2);
      dudxOde=mm.mapFunctionDer(u2);
      fluxOde = mm.mapFunction(f2);
      dupdxOde=mm.mapFunctionDer(up2);
      f = callVarargFunc(self.odeFunc, ...
        {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
    end
    
    function [dFdv,dFdvDot]=calcDOdeDv(self, time, u2, up2, f2, v, vDot)
      mOde = self.numODEEquations;
      mm = self.meshMapper;
      uOde=mm.mapFunction(u2);
      upOde=mm.mapFunction(up2);
      dudxOde=mm.mapFunctionDer(u2);
      fluxOde = mm.mapFunction(f2);
      dupdxOde=mm.mapFunctionDer(up2);
      f0 = callVarargFunc(self.odeFunc, ...
        {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
      if size(f0,1) ~= mOde
        error('Number of rows returned from ODE function must be %d.\n', ...
          mOde);
      end
      sqrtEps = sqrt(eps);
      dFdv = zeros(mOde, mOde);
      for i=1:mOde
        vSave = v(i);
        h = sqrtEps * max(vSave, 1);
        v(i) = v(i) + h;
        fp = callVarargFunc(self.odeFunc, ...
          {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
        dFdv(:,i) = (fp-f0)/h;
        v(i) = vSave;
      end
      if nargout < 2
        return;
      end
      dFdvDot = zeros(mOde, mOde);
      for i=1:mOde
        vDotSave = vDot(i);
        h = sqrtEps * max(vDotSave, 1);
        vDot(i) = vDot(i) + h;
        fp = callVarargFunc(self.odeFunc, ...
          {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
        dFdvDot(:,i) = (fp-f0)/h;
        vDot(i) = vDotSave;
      end
    end
    
    function [dFdu,dFduDot]=calcDOdeDu(self, time, u2, up2, f2, v, vDot)
      [numDepVars,numNodes] = size(u2);
      numFEMEqns = numDepVars*numNodes;
      mm = self.meshMapper;
      uOde=mm.mapFunction(u2);
      upOde=mm.mapFunction(up2);
      dudxOde=mm.mapFunctionDer(u2);
      fluxOde = mm.mapFunction(f2);
      dupdxOde=mm.mapFunctionDer(up2);
      f0 = callVarargFunc(self.odeFunc, ...
        {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
      if size(f0,1) ~= self.numODEEquations
        error('Number of rows returned from ODE function must be %d.\n', ...
          self.numODEEquations);
      end
      sqrtEps = sqrt(eps);
      dFdu = zerosLike(self.numODEEquations, numDepVars, numNodes, u2);
      dni = mm.destNodeIndex;
      for ii=1:length(dni)
        i = dni(ii);
        for j=1:numDepVars
          usave = u2(j,i);
          h = sqrtEps * max(usave, 1);
          u2(j,i) = u2(j,i) + h;
          uOde=mm.mapFunction(u2);
          dudxOde=mm.mapFunctionDer(u2);
          f = callVarargFunc(self.odeFunc, ...
            {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
          dFdu(:,j,i) = (f-f0)/h;
          u2(j,i) = usave;
        end
      end
      dFdu = reshape(dFdu, self.numODEEquations, numFEMEqns);
      if nargout < 2
        return;
      end
      uOde=mm.mapFunction(u2);
      dudxOde=mm.mapFunctionDer(u2);
      dFduDot = zerosLike(self.numODEEquations, numDepVars, numNodes, up2);
      for ii=1:length(dni)
        i = dni(ii);
        for j=1:numDepVars
          upsave = up2(j,i);
          h = sqrtEps * max(upsave, 1);
          up2(j,i) = up2(j,i) + h;
          upOde=mm.mapFunction(up2);
          dupdxOde=mm.mapFunctionDer(up2);
          f = callVarargFunc(self.odeFunc, ...
            {time, v, vDot, self.odeMesh, uOde, dudxOde, fluxOde, upOde, dupdxOde});
          dFduDot(:,j,i) = (f-f0)/h;
          up2(j,i) = upsave;
        end
      end
      dFduDot = reshape(dFduDot, self.numODEEquations, numFEMEqns);
    end
    
    function vode=getVFromSysVec(self,v)
      v=v(:);
      vode = v(self.vRange);
      %vode = v(self.eRange);
    end
    
    function vode=getDOFsFromSysVec(self,v)
      v=v(:);
      vode = v(self.eRange);
    end
    
    function vode=getLFromSysVec(self,v)
      v=v(:);
      vode = v(self.lRange);
    end
    
  end
  
  methods(Access=private)
  end
  
  properties(Access=private)
    odeFunc, odeICFunc, odeMesh;
    y0Ode;
    numODELagMult;
    meshMapper;
    vRange, eRange, lRange;
    lagMultAlg, lagMultEqns;
    diagnosticPrint;
    testFunctionIndex;
  end
  
end

