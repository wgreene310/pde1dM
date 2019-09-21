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
%   Copyright (C) 2016-2019 William H. Greene

classdef PDEOptions
  properties
    icDiagnostics, eqnDiagnostics, addLagMultVector, useDiagMassMat;
    vectorized, numIntegrationPoints, hasODE, analyticalJacobian;
  end
  
  methods
    function obj = PDEOptions()
      obj.icDiagnostics=0;
      obj.eqnDiagnostics=0;
      obj.addLagMultVector = false;
      obj.useDiagMassMat = false;
      obj.vectorized = false;
      obj.numIntegrationPoints = 2;
      obj.hasODE = false;
      obj.analyticalJacobian = false;
    end
  end
end

