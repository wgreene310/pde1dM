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
% Copyright (C) 2016-2021 William H. Greene

function [y0_new, yp0_new, resnrm] = decicShampine (odefun, t0, y0, fixed_y0, yp0, ...
  fixed_yp0, options)

if (nargin < 6 || nargin > 7)
  error('decic:nrhs', ...
    'Illegal number of input arguments passed to decic.');
end

p=inputParser;
validHandle = @(x) isa(x, 'function_handle');
p.addRequired('odeFunc', validHandle);
p.addRequired('t0', @(t0) isnumeric (t0) && isscalar(t0));
isNumVec = @(x) isnumeric (x) && isvector(x);
p.addRequired('y0', isNumVec);
p.addRequired('fixed_y0', isNumVec);
p.addRequired('yp0', isNumVec);
p.addRequired('fixed_yp0', isNumVec);
p.addParameter('RelTol', 1e-3, @(x) isscalar (x));
p.addParameter('AbsTol', 1e-6, @(x) isscalar (x));
p.addParameter('ICDiagnostics', 0);
p.addParameter('Jacobian', [], @(x) validHandle(x) || (iscell(x) && length(x)==2));
p.parse(odefun, t0, y0, fixed_y0, yp0,fixed_yp0, options);
relTol=p.Results.RelTol;
absTol=p.Results.AbsTol;
icdiag = p.Results.ICDiagnostics;
haveJac = 0;

jac = p.Results.Jacobian;
if(~isempty(jac))
  if(iscell(jac))
    dfDy = jac{1};
    dfDyp = jac{2};
    checkJacSize(dfDy, dfDyp, n);
    haveJac = 1;
  else
    haveJac = 2;
  end
end

% make sure they are column vectors
y0 = y0(:); yp0 = yp0(:);

n  = length (y0);
checkLen(n, fixed_y0);
checkLen(n, yp0);
checkLen(n, fixed_yp0);

free_y0 = ~fixed_y0;
nl = sum (free_y0);
anyFreeY0 = nl>0;
free_yp0 = ~fixed_yp0;
nu = sum (free_yp0);
anyFreeYp0 = nu>0;

if (n - nl - nu > 0)
  error ('decic:too_many_fixed', ...
    'decic: you cannot fix more than %d components', n);
end

%fprintf('anyFreeY0=%d, anyFreeYp0=%d\n', anyFreeY0, anyFreeYp0);

maxIter = 10;
it = 0;
y0_new = y0; yp0_new = yp0;
if icdiag
  fprintf('decic: AbsTol=%g, RelTol=%g\n', absTol, relTol);
  prtShortVec(y0, 'y0');
  prtShortVec(yp0, 'yp0');
  prtShortVec(odefun(t0,y0, yp0), 'res0');
end
if icdiag>1
  prtShortVec(fixed_y0, 'fixed_y0');
  prtShortVec(fixed_yp0, 'fixed_yp0');
end
while(it <= maxIter)
  res = odefun(t0,y0_new, yp0_new);
  resnrm=norm(res);
  maxRes = max(max(relTol*abs(res),absTol));
  if(icdiag > 1)
    fprintf('iteration=%d, maxres=%12.3e\n', it, maxRes);
  end
  if(icdiag > 2)
    prtShortVec(res, 'res');
  end
  if(maxRes <= absTol)
    return;
  end
  res=res(:);
  
  dfDy = []; dfDyp = [];
  if(haveJac == 0)
    % calculate by forward difference
    if(anyFreeY0)
      dfDy=getDfDy(odefun, t0, y0_new, yp0_new, res, options);
    end
    if(anyFreeYp0)
      dfDyp=getDfDyp(odefun, t0, y0_new, yp0_new, res, options);
    end
  elseif(haveJac == 2)
    [dfDy, dfDyp] = options.Jacobian(t0, y0_new, yp0_new);
    checkJacSize(dfDy, dfDyp, n);
  end
  %dfDy
  %dfDyp
  
  % remove columns for the components of yp0 that are fixed
  dfDyp = dfDyp(:, free_yp0);
  % remove columns for the components of y0 that are fixed
  dfDy = dfDy(:, free_y0);
  
  if (~anyFreeY0)
    % must do QR on full matrix to get full rank-revealing algorithm
    [Q,R,E] = qr(full(dfDyp));
    rr=rankR(R);
    dd=1:rr;
    d = -Q'*res;
    yp0_new =   yp0_new + E(:,dd)*(R(dd,dd)\d(dd));
  elseif (~anyFreeYp0)
    % must do QR on full matrix to get full rank-revealing algorithm
    [Q,R,E] = qr(full(dfDy));
    rr=rankR(R);
    dd=1:rr;
    d = -Q'*res;
    y0_new = y0_new  + E(:,dd)*(R(dd,dd)\d(dd));
  else
    % must do QR on full matrix to get full rank-revealing algorithm
    [Q,R,E] = qr(full(dfDyp));
    algdofs = abs(diag(R))<100*eps;
    %algdofs'
    anyAlgDofs = any(algdofs);
    difdofs=~algdofs;
    R11 = R(difdofs, difdofs);
    %rank(R11)
    d = -Q'*res;
    S = Q'*dfDy;
    if(anyAlgDofs)
      S2122 = S(algdofs,:);
      %S2122
      if(0)
        w=S2122\d(algdofs);
      else
        [Qs,Rs,Es] = qr(S2122);
        % FIXME: need to check rank here
        w = Es*(Rs\(Qs'*d(algdofs)));
        if(icdiag > 3)
          prtMat(Qs, 'Qs');
          prtMat(Rs, 'Rs');
          prtMat(Es, 'Es');
        end
      end
      if(icdiag > 2)
        prtShortVec(w, 'w');
      end
      y0_new(free_y0) = y0_new(free_y0) + w;
      w1p = R11\(d(difdofs) - S(difdofs,:)*w);
    else
      w1p = R11\d(difdofs);
    end
    wp = zeros(nu,1);
    wp(difdofs) = w1p;
    yp0_new(free_yp0) = yp0_new(free_yp0) + E*wp;
    if(icdiag > 2)
      prtShortVec(w1p, 'w1p');
      prtShortVec(y0_new, 'y0_new');
      prtShortVec(yp0_new, 'yp0_new');
    end
  end
  it = it + 1;
end

warning ('decic: Failed to obtain a converged set of consistent initial conditions.',...
  ' This might cause the ODE to DAE solver to fail in the first step.');

end

function dfDy=getDfDy(odefun, t, y, yp, r, options)
n = length(y);
dfDy = zeros(n,n);
sqrtEps = sqrt(eps);
for i=1:n
  ysave = y(i);
  delta = sqrtEps*max(abs(y(i)), 1);
  y(i) =   y(i) + delta;
  rp=odefun(t, y, yp);
  dfDy(:,i) = (rp-r)/delta;
  y(i) = ysave;
end
end

function dfDyp=getDfDyp(odefun, t, y, yp, r, options)
n = length(y);
dfDyp = zeros(n,n);
sqrtEps = sqrt(eps);
for i=1:n
  ypsave = yp(i);
  delta = sqrtEps*max(abs(yp(i)), 1);
  yp(i) = yp(i) + delta;
  rp=odefun(t, y, yp);
  dfDyp(:,i) = (rp-r)/delta;
  yp(i) = ypsave;
end
end

function checkJacSize(dfDy, dfDyp, n)
[md,nd]=size(dfDy); [mp,np]=size(dfDyp);
if(md~=n || nd~=n || mp~=n || np~=n)
  msg=sprintf('decic: Jacobian matrices must be %d x %d', n, n);
  error ('decic:jac_err', msg);
end
end

function rank=rankR(R)
adr=abs(diag(R));
tol=eps*max(adr);
rank=nnz(adr>tol);
end

function value = getfieldi(S,field)
names   = fieldnames(S);
isField = strcmpi(field,names);

if any(isField)
  value = S.(names{isField});
else
  value = [];
end
end

function checkLen(n, x)
if(length(x) ~= n)
  error('Length of input argument "%s" must equal %d.', ...
    inputname(2), n);
end
end
