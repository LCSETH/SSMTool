%% Initialize 
clear all; close all; clc; 

%% Define Mechanical System -----------------------------------------------

% ----- System parameters -----
syms x1 x2 x3 x4 t real
ndof = 2;
ndof_spv = 2*ndof;

m1 = 1;
m2 = 1;
c1 = 0.03;
c2 = 0.03*sqrt(3);
k1 = 3;
k2 = 3;
kappa = 0.4;   
gamma_3 = -0.6; 
gamma_5 = 1.2;   
P = 3;
omega_f = 1;
power = 5;

% ----- Second order form -----
% M\ddot{x} + C\dot{x} + Kx + fnl(x,\dot{x}) = \epsilon*fphi(phi)
M = [m1,0;0,m2];
C = [c1+c2,-c2;-c2,c1+c2];
K = [k1+k2,-k2;-k2,k2+k2];
fnl = [gamma_3*x3^3+gamma_5*x3^5+kappa*x1^3;0];
fphi = [P*cos(omega_f*t);0];

% ----- First order form -----
% \dot{x} = Ax + Fnl(x) + \epsilon*Fphi
A = [zeros(ndof),eye(ndof);-M\K,-M\C];
Fnl = [zeros(ndof,1);-M\fnl];
Fphi = [zeros(ndof,1);M\fphi];

% ----- Linear transformation matrix ------
[X,D] = eig(A);
D = diag(D);
[~,k] = sort(D,'ascend');
k = [3;4;1;2]; % Sort for SSM paper [Ponsioen et al.]

lambda = D(k);
T = X(:,k);
ct = 1;
for i = 1:ndof_spv
   T(:,i) = T(:,i)/(ct*T(1,i)); 
end 

% ----- Eigenvector needed for nonlinear contributions ------
Tinv = inv(T);
Tcol_i_3 = Tinv(:,3);
Tcol_i_4 = Tinv(:,4);

max_order = 6;  

%% Autonomous SSM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%                                         %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%          Autonomous SSM                 %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%                                         %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_script = tic;
nvar  = 2; 
lambda_E =  lambda(1:nvar);

R_amp = [];

% ----- Initialize W0 and set linear part -----
w01 = zeros(repmat(max_order+1,1,nvar));
w02 = zeros(repmat(max_order+1,1,nvar));
w03 = zeros(repmat(max_order+1,1,nvar));
w04 = zeros(repmat(max_order+1,1,nvar));

w01(2,1) = 1;
w01ij = [2,1];
w01ij = w01ij-ones(size(w01ij));

w02(1,2) = 1; 
w02ij = [1,2];
w02ij = w02ij-ones(size(w02ij));

w03ij = [];
w04ij = [];

W0 = {w01,w02,w03,w04};
W0ij = {w01ij,w02ij,w03ij,w04ij};

% ----- Initialize R0 and set linear part -----
r01 = zeros(repmat(max_order+1,1,nvar));
r02 = zeros(repmat(max_order+1,1,nvar));

r01(2,1) = lambda(1);
r01ij = [2,1];
r01ij = r01ij-ones(size(r01ij));

r02(1,2) = lambda(2);
r02ij = [1,2];
r02ij = r02ij-ones(size(r02ij));

R0 = {r01,r02};

R0ij{1} = r01ij;
R0ij{2} = r02ij;

% ----- Define internal resonances -----
in_res = [];

for i=2:ceil(max_order/2)
   res_block = [i,i-1;i-1,i];
   in_res = [in_res;res_block]; 
end
          
in_res_order = unique(sum(in_res,2));
in_res_cor = repmat([1;2],[size(in_res,1)/2,1]);


% ----- Initialize polynomial matrix for nonlinear contributions -----
Hpx1ij = cell(1,power);
Hpx1 = cell(1,power);

Hpx3ij = cell(1,power);
Hpx3 = cell(1,power);

for i=1:power
    Hpx1{i} = zeros(repmat(max_order+1,1,nvar));
    Hpx3{i} = zeros(repmat(max_order+1,1,nvar));
end

for k=2:max_order
    start_iteration = tic;
    fprintf('Order = %d \n',k)
    
    order = k;   
    
    % Compute all coefficients for the current order
    ncoef = nch(order,nvar);
    i_dummy = [order,zeros(1,nvar-1)];
    index_corder = zeros(ncoef,nvar);
    index_corder(1,:) = i_dummy;
    
    for i=2:ncoef
        i_dummy = genlexd(i_dummy,nvar);
        index_corder(i,:) = i_dummy;
    end

    % ----- Nonlinear Contributions -----
    
    % Substitute T*W0 into the physical coordinates
    % x1
    [Px1,Px1ij] = man2cor(W0,T,1,ndof_spv,nvar,max_order);
    
    % Substitute T*W0 into the physical coordinates
    % x3
    [Px3,Px3ij] = man2cor(W0,T,3,ndof_spv,nvar,max_order);
    
    
    % Compute x1^power  
    % (This also saves x3^(power-1), x3^(power-2),...,x3^1)
    Hpx1ij{1} = Px1ij;
    Hpx1{1} = Px1;
    [Hpx1,Hpx1ij] = poly_power(Px1,Px1ij,Hpx1,Hpx1ij,nvar,k,power);
    
    % Compute x3^power  
    % (This also saves x3^(power-1), x3^(power-2),...,x3^1)
    Hpx3ij{1} = Px3ij;
    Hpx3{1} = Px3;
    [Hpx3,Hpx3ij] = poly_power(Px3,Px3ij,Hpx3,Hpx3ij,nvar,k,power);
    
    %%%--------------------------
    
    in_res_CO = isempty(find(in_res_order==k,1));
    
    % -------
    if in_res_CO
        spv_index_res = [];
    else
            
        [C,index_co,~] = intersect(index_corder,in_res,'rows','stable');
        index_res = find(ismember(in_res,C,'rows'));

        coef_index_res = zeros(1,numel(index_res));

        for q=1:numel(index_res)
            coef_index_res(q) = find(ismember(index_corder,in_res(index_res(q),:),'rows'));
        end

        spv_index_res_doubles = in_res_cor(index_res).';
        spv_index_res =  unique(spv_index_res_doubles);

    end
    
    spv_index_rem = setdiff(1:ndof_spv,spv_index_res);
    
    %---

    parfor l=spv_index_rem
        % Invariance equation: A*W0 + G(W0) = dW0ds*R0
        W = W0{l};
        Wij = W0ij{l};        
        GW = -(1/m1)*Tcol_i_3(l)*(gamma_3*Hpx3{3}+gamma_5*Hpx3{5}+kappa*Hpx1{3});
        [WR,WRij] = poly_product_DWR(W,Wij,R0,R0ij,nvar,k,max_order);   
        
        for j=1:ncoef
            den = lambda(l) - (index_corder(j,:)*lambda_E);          
            i_cell = num2cell(index_corder(j,:)+ones(size(index_corder(j,:))));
            i_ind = sub2ind(size(W),i_cell{:});         
            W(i_ind) = (1/den)*(WR(i_ind)-GW(i_ind));
        end
        
        xi = find(W);
        Xi_cell = cell(1,nvar);
        [Xi_cell{:}] = ind2sub(size(W),xi);
        Xi = [Xi_cell{:}];
        W0ij{l} =  Xi-ones(size(Xi));
        W0{l} = W; 
    end
    
    
    for l=spv_index_res
        
        W = W0{l};
        Wij = W0ij{l};
        GW = -(1/m1)*Tcol_i_3(l)*(gamma_3*Hpx3{3}+gamma_5*Hpx3{5}+kappa*Hpx1{3});
        ncoef_l_res = coef_index_res(spv_index_res_doubles==l);
        ncoef_l_rem = setdiff(1:ncoef,ncoef_l_res);
         
        [WR,WRij] = poly_product_DWR(W,Wij,R0,R0ij,nvar,k,max_order);  
        
        for j=ncoef_l_res
            den = lambda(l) - (index_corder(j,:)*lambda_E);           
            i_cell = num2cell(index_corder(j,:)+ones(size(index_corder(j,:))));
            i_ind = sub2ind(size(W),i_cell{:});       
            
            R = R0{l};
            Rij = R0ij{l};
            R(i_ind) = -(WR(i_ind)-GW(i_ind));
            W(i_ind) = 0;  
            xi = find(R);
            Xi_cell = cell(1,nvar);
            [Xi_cell{:}] = ind2sub(size(R),xi);
            Xi = [Xi_cell{:}];
            R0ij{l} =  Xi-ones(size(Xi));
            R0{l} = R;
            
            R_amp = [R_amp, abs(R(i_ind))];

            
        end
        
        for j=ncoef_l_rem
            den = lambda(l) - (index_corder(j,:)*lambda_E);      
            i_cell = num2cell(index_corder(j,:)+ones(size(index_corder(j,:))));
            i_ind = sub2ind(size(W),i_cell{:});      
            W(i_ind) = (1/den)*(WR(i_ind)-GW(i_ind));
        end
        
        xi = find(W);
        Xi_cell = cell(1,nvar);
        [Xi_cell{:}] = ind2sub(size(W),xi);
        Xi = [Xi_cell{:}];
        W0ij{l} =  Xi-ones(size(Xi));
        W0{l} = W;
         
    end
    end_iteration = toc(start_iteration);
    fprintf('Elapsed time = %0.5f s \n',end_iteration);
    
end
end_script = toc(start_script);
fprintf('\n')
fprintf('Total computational time = %0.5f s \n',end_script);

%% Non-autonomous SSM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%                                         %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%           Non-autonomous SSM            %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%                                         %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
symbolic = 1;
start_script = tic;

% ----- Initialize W1 -----

syms omega
w11 = sym(zeros([repmat(max_order+1,1,nvar),2]));
w12 = sym(zeros([repmat(max_order+1,1,nvar),2]));
w13 = sym(zeros([repmat(max_order+1,1,nvar),2]));
w14 = sym(zeros([repmat(max_order+1,1,nvar),2]));

w11ij = [];
w12ij = [];
w13ij = [];
w14ij = [];

W1 = {w11,w12,w13,w14};
W1ij = {w11ij,w12ij,w13ij,w14ij};

% ----- Initialize R1 -----

r11 = sym(zeros([repmat(max_order+1,1,nvar),2]));
r12 = sym(zeros([repmat(max_order+1,1,nvar),2]));

r11ij = [];
r12ij = [];

R1 = {r11,r12};
R1ij{1} = r11ij;
R1ij{2} = r12ij;

% % ----- Define internal resonances -----
in_res = [];
in_res = zeros(2,2);
in_res_ab = [1;2];
for i=1:floor(max_order/2)
    a = [1;2];
    A = i*ones(2,2);
    
    B = [i+1,i-1;i-1,i+1];
    b = [2;1];
    
    in_res = [in_res;A;B];
    in_res_ab = [in_res_ab;a;b];
end

in_res_order = unique(sum(in_res,2));
in_res_cor = repmat([1;2],[size(in_res,1)/2,1]);


% ----- Initialize polynomial matrix for nonlinear contributions -----

Hprod_alpha = sym(zeros([repmat(max_order+1,1,nvar),2]));
Hprod_beta = sym(zeros([repmat(max_order+1,1,nvar),2]));

F = zeros([repmat(max_order+1,1,nvar),2]);
F(1,1,1) = P/2;
F(1,1,2) = P/2;


for k=1:max_order
    start_iteration = tic;
    fprintf('Order = %d \n',k-1)
    
    order = k-1;   
    
    % Compute all coefficients for the current order
    ncoef = nch(order,nvar);
    i_dummy = [order,zeros(1,nvar-1)];
    index_corder = zeros(ncoef,nvar);
    index_corder(1,:) = i_dummy;
    
    for i=2:ncoef
        i_dummy = genlexd(i_dummy,nvar);
        index_corder(i,:) = i_dummy;
    end

    % -----  Nonlinear Contributions --------
    
    % Substitute T*W1 into the physical coordinates
    % x1
    [Qx1,Qx1ij] = man2cor_ab(W1,T,1,ndof_spv,nvar,max_order);
    
    % Substitute T*W1 into the physical coordinates
    % x3
    [Qx3,Qx3ij] = man2cor_ab(W1,T,3,ndof_spv,nvar,max_order);

    % Compute alpha
    Palpha = 3*gamma_3*Hpx3{2} + 5*gamma_5*Hpx3{4};
    Palphaij = unique([Hpx3ij{2};Hpx3ij{4}],'rows');
    [Hprod_alpha,Hprod_alphaij] = poly_product_ab(Palpha,Palphaij,Qx3,Qx3ij,Hprod_alpha,nvar,order);
    
    %Compute beta
    Pbeta = 3*kappa*Hpx1{2};
    Pbetaij = unique([Hpx1ij{2}],'rows');
    [Hprod_beta,Hprod_betaij] = poly_product_ab(Pbeta,Pbetaij,Qx1,Qx1ij,Hprod_beta,nvar,order);

    
    %%%--------------------------
    
    in_res_CO = isempty(find(in_res_order==order,1));
    
    % -------
    if in_res_CO
        spv_index_res = [];
    else
            
    [C,index_co,~] = intersect(index_corder,in_res,'rows','stable');
    index_res = find(ismember(in_res,C,'rows'));
    
    coef_index_ab = in_res_ab(index_res);
    coef_index_res = zeros(1,numel(index_res));

    for q=1:numel(index_res)
        coef_index_res(q) = find(ismember(index_corder,in_res(index_res(q),:),'rows'));
    end
    
    spv_index_res_doubles = in_res_cor(index_res).';
    spv_index_res =  unique(spv_index_res_doubles);

    end

    spv_index_rem = setdiff(1:ndof_spv,spv_index_res);
    % -------
    
    
    parfor l=spv_index_rem  %parfor
        % Invariance equation: A*W1 + \partial_x{G(W0)}*W1 + F(phi) =
        % dW0ds*R1 + dW1ds*R0 + dW1dphi*\Omega
        
        W1dum = W1{l};
        W1ijdum = W1ij{l};
        
        W1dum_a = W1dum(:,:,1);
        W1dum_b = W1dum(:,:,2);
        
        W0dum = W0{l};
        W0ijdum = W0ij{l};
        
        GW = -(1/m1)*Tcol_i_3(l)*(Hprod_alpha+Hprod_beta);
        FT = (1/m1)*Tcol_i_3(l)*F;
        
        [W1R0,W1R0ij] = poly_product_DW1R0(W1dum,W1ijdum,R0,R0ij,nvar,order,max_order,symbolic);   
        [W0R1,W0R1ij] = poly_product_DW0R1(W0dum,W0ijdum,R1,R1ij,nvar,order,max_order,symbolic); 
        
        alpha = W0R1(:,:,1) + W1R0(:,:,1) - FT(:,:,1) - GW(:,:,1);
        beta  = W0R1(:,:,2) + W1R0(:,:,2) - FT(:,:,2) - GW(:,:,2);
        
        for j=1:ncoef

                den_a = lambda(l) - index_corder(j,:)*lambda_E-1j*omega;    
                den_b = lambda(l) - index_corder(j,:)*lambda_E+1j*omega;  
                
                i_cell = num2cell(index_corder(j,:)+ones(size(index_corder(j,:))));
                i_ind = sub2ind(size(W1dum_a),i_cell{:});  
                
                W1dum_a(i_ind) = (1/den_a)*alpha(i_ind);
                W1dum_b(i_ind) = (1/den_b)*beta(i_ind);
        
        end
        
        W1ijdum_ab = cell(1,2);
        
        xi = find(W1dum_a);
        Xi_cell = cell(1,nvar);
        [Xi_cell{:}] = ind2sub(size(W1dum_a),xi);
        Xi = [Xi_cell{:}];
        W1dum(:,:,1) = W1dum_a;
        W1ijdum_ab{1} =  (Xi-ones(size(Xi))).';
        
        xi = find(W1dum_b);
        Xi_cell = cell(1,nvar);
        [Xi_cell{:}] = ind2sub(size(W1dum_b),xi);
        Xi = [Xi_cell{:}];
        W1dum(:,:,2) = W1dum_b;
        W1ijdum_ab{2} = (Xi-ones(size(Xi))).';
        
        W1ij{l} = unique([W1ijdum_ab{:}].','rows');
        W1{l} = W1dum; 
        
        
    end
    
    
    for l=spv_index_res
        
        W1dum = W1{l};
        W1ijdum = W1ij{l};
        
        W1dum_a = W1dum(:,:,1);
        W1dum_b = W1dum(:,:,2);
        
        W0dum = W0{l};
        W0ijdum = W0ij{l};
        
        GW = -(1/m1)*Tcol_i_3(l)*(Hprod_alpha+Hprod_beta);
        FT =  (1/m1)*Tcol_i_3(l)*F;
        
        [W1R0,W1R0ij] = poly_product_DW1R0(W1dum,W1ijdum,R0,R0ij,nvar,order,max_order,symbolic);   
        [W0R1,W0R1ij] = poly_product_DW0R1(W0dum,W0ijdum,R1,R1ij,nvar,order,max_order,symbolic); 
        
        alpha = W0R1(:,:,1) + W1R0(:,:,1) - FT(:,:,1) - GW(:,:,1);
        beta  = W0R1(:,:,2) + W1R0(:,:,2) - FT(:,:,2) - GW(:,:,2);

        ncoef_l_res = coef_index_res(spv_index_res_doubles==l); 
        ncoef_l_ab = coef_index_ab(spv_index_res_doubles==l);
        ncoef_l_rem = setdiff(1:ncoef,ncoef_l_res);
    
        R1dum = R1{l};
        R1ijdum = R1ij{l};

        R1dum_a = R1dum(:,:,1);
        R1dum_b = R1dum(:,:,2);
           
        in = 0;
        for j=ncoef_l_res
            in = in+1;   
            i_cell = num2cell(index_corder(j,:)+ones(size(index_corder(j,:))));
            i_ind = sub2ind(size(W1dum_a),i_cell{:});  
            
            den_a = lambda(l) - index_corder(j,:)*lambda_E-1j*omega;    
            den_b = lambda(l) - index_corder(j,:)*lambda_E+1j*omega;  
              
            
            if l==1 || l==2
                if ncoef_l_ab(in)==1

                    R1dum_a(i_ind) = -alpha(i_ind);
                    R1dum_b(i_ind) = 0;

                    W1dum_a(i_ind) = 0;  
                    W1dum_b(i_ind) = (1/den_b)*beta(i_ind);
                
                elseif ncoef_l_ab(in)==2
                    
                    R1dum_a(i_ind) = 0;
                    R1dum_b(i_ind) = -beta(i_ind);

                    W1dum_a(i_ind) = (1/den_a)*alpha(i_ind);  
                    W1dum_b(i_ind) = 0;  

                else
                    error('Error in in_res_ab');
                end
            else
                error('Error: wrong resonance index (l~=(1 || 2))');
            end
            
            R1ijdum_ab = cell(1,2);

            xi = find(R1dum_a);
            Xi_cell = cell(1,nvar);
            [Xi_cell{:}] = ind2sub(size(R1dum_a),xi);
            Xi = [Xi_cell{:}];
            R1dum(:,:,1) = R1dum_a;
            R1ijdum_ab{1} =  (Xi-ones(size(Xi))).';

            xi = find(R1dum_b);
            Xi_cell = cell(1,nvar);
            [Xi_cell{:}] = ind2sub(size(R1dum_b),xi);
            Xi = [Xi_cell{:}];
            R1dum(:,:,2) = R1dum_b;
            R1ijdum_ab{2} =  (Xi-ones(size(Xi))).';

            R1ij{l} = unique([R1ijdum_ab{:}].','rows');
            R1{l} = R1dum; 
        end
        
        for j=ncoef_l_rem
                den_a = lambda(l) - index_corder(j,:)*lambda_E-1j*omega;    
                den_b = lambda(l) - index_corder(j,:)*lambda_E+1j*omega;  
                
                i_cell = num2cell(index_corder(j,:)+ones(size(index_corder(j,:))));
                i_ind = sub2ind(size(W1dum_a),i_cell{:});  
                
                W1dum_a(i_ind) = (1/den_a)*alpha(i_ind);
                W1dum_b(i_ind) = (1/den_b)*beta(i_ind);
        end
        
        
        W1ijdum_ab = cell(1,2);
        
        xi = find(W1dum_a);
        Xi_cell = cell(1,nvar);
        [Xi_cell{:}] = ind2sub(size(W1dum_a),xi);
        Xi = [Xi_cell{:}];
        W1dum(:,:,1) = W1dum_a;
        W1ijdum_ab{1} =  (Xi-ones(size(Xi))).';
        
        xi = find(W1dum_b);
        Xi_cell = cell(1,nvar);
        [Xi_cell{:}] = ind2sub(size(W1dum_b),xi);
        Xi = [Xi_cell{:}];
        W1dum(:,:,2) = W1dum_b;
        W1ijdum_ab{2} =  (Xi-ones(size(Xi))).';
        
        W1ij{l} = unique([W1ijdum_ab{:}].','rows');
        W1{l} = W1dum; 
   
    end
    end_iteration = toc(start_iteration);
    fprintf('Elapsed time = %0.5f s \n',end_iteration);
    
end
end_script = toc(start_script);
fprintf('\n')
fprintf('Total computational time = %0.5f s \n',end_script);

syms rho psi omega epsilon real
syms x1 x2 x3 p1 p2 t real

odd = mod(max_order-1,2);

if odd == 1
   M = floor((max_order-1)/2);
   N = M;
else
   M = floor((max_order-1)/2);
   N = M-1;
end

R1dum = R1{1};

figure
subplot(1,2,1)
spy(R1dum(:,:,1),'r')
subplot(1,2,2)
spy(R1dum(:,:,2),'b')

c0 = R1dum(1,1,1);

if abs(real(c0))<1e-15
    f1 = 0;
    g2 = 0;
else
    f1 = real(c0);
    g2 = real(c0);
end

if abs(imag(c0))<1e-15
    f2 = 0;
    g1 = 0;
else
    f2 = imag(c0);
    g1 = imag(c0);
end

for i=1:M  % 0 for 0th order expansion in W1 otherwise replace 0 for M
    f1 = f1 + (real(R1dum(i+1,i+1,1)) + real(R1dum(i+2,i,2)))*rho^(2*i);
    f2 = f2 + (imag(R1dum(i+1,i+1,1)) - imag(R1dum(i+2,i,2)))*rho^(2*i);
    g1 = g1 + (imag(R1dum(i+1,i+1,1)) + imag(R1dum(i+2,i,2)))*rho^(2*i);
    g2 = g2 + (real(R1dum(i+1,i+1,1)) - real(R1dum(i+2,i,2)))*rho^(2*i);  
end

R0dum = R0{1};
R0ijdum = R0ij{1};

R0cdum = R0{2};
R0cijdum = R0ij{2};


a = 0;
b = 0;

for i = 0:N    
    
    beta = R0dum(i+2,i+1);
    
    if abs(real(beta))<1e-15
        beta_real = 0;
    else 
        beta_real = real(beta);
    end
    
    if abs(imag(beta))<1e-15
        beta_imag = 0;
    else 
        beta_imag = imag(beta);
    end
    
    a = a + beta_real*rho^(2*i+1);
    b = b + beta_imag*rho^(2*i);
    
end

rhod =  a + epsilon*(f1*cos(psi) + f2*sin(psi));
psid =  (b-omega) + (epsilon/rho)*(g1*cos(psi) - g2*sin(psi));

disc = epsilon^2*(f1^2+f2^2)-a^2;
Kp = (-epsilon*f2 + sqrt(disc))/(a-epsilon*f1);
Km = (-epsilon*f2 - sqrt(disc))/(a-epsilon*f1);

Fimp_p = (b-omega).*rho + epsilon.*(g1.*(1-Kp.^2)./(1+Kp.^2)-g2.*(2.*Kp)./(1+Kp.^2));
Fimp_m = (b-omega).*rho + epsilon.*(g1.*(1-Km.^2)./(1+Km.^2)-g2.*(2.*Km)./(1+Km.^2));

FRP_func_p_a = @(rho,omega,epsilon)eval(Fimp_p);
FRP_func_m_a = @(rho,omega,epsilon)eval(Fimp_m);

p = [p1;p2];
spv = [x1;x2];
rhs= subs([rhod;psid],[rho;psi;omega;epsilon],[x1;x2;p1;p2]);

%% Create function files

matlabFunction(rhs,'file','mech_sys_isola','Vars',{spv,p});

fileID = fopen('mech_sys_isola_dx.m','w');
fprintf(fileID,strcat('function J = mech_sys_isola_dx(x,p)','\n'));
for i=1:numel(spv)
    fprintf(fileID,strcat(char(spv(i)),sprintf('=x(%i,:);',i),'\n'));
end

for i=1:numel(p)
    fprintf(fileID,strcat(char(p(i)),sprintf('=p(%i,:);',i),'\n'));
end

fprintf(fileID,strcat(sprintf('J=zeros(%i,%i,numel(x(1,:)));',numel(spv),numel(spv)),'\n'));
    
for i=1:numel(spv)
    for j=1:numel(spv)
        DfDx = vectorize(jacobian(rhs(i),spv(j)));
        fprintf(fileID,strcat(sprintf('J(%i,%i,:)=',i,j),char(DfDx),';\n'));
    end
end
fprintf(fileID,'end');
fclose(fileID);


fileID = fopen('mech_sys_isola_dp.m','w');
fprintf(fileID,strcat('function J = mech_sys_isola_dp(x,p)','\n'));
for i=1:numel(spv)
    fprintf(fileID,strcat(char(spv(i)),sprintf('=x(%i,:);',i),'\n'));
end

for i=1:numel(p)
    fprintf(fileID,strcat(char(p(i)),sprintf('=p(%i,:);',i),'\n'));
end

fprintf(fileID,strcat(sprintf('J=zeros(%i,%i,numel(p(1,:)));',numel(spv),numel(p)),'\n'));

for i=1:numel(spv)
    for j=1:numel(p)
        DfDp = vectorize(jacobian(rhs(i),p(j)));
        fprintf(fileID,strcat(sprintf('J(%i,%i,:)=',i,j),char(DfDp),';\n'));
    end
end
fprintf(fileID,'end');
fclose(fileID);

%% Plot zero-leve set of G(\rho,\Omega)

epsilon_p = 0.0025;  
                      
pp_rho = 710;
pp_omega = 200;

[Xrho,Yomega] = meshgrid(linspace(0.001,0.2,pp_rho),linspace(1.69,1.78,pp_omega));
Fimpeval_p = FRP_func_p_a(Xrho,Yomega,epsilon_p);
Fimpeval_m = FRP_func_m_a(Xrho,Yomega,epsilon_p);

delta = 1.05e-4; 

for i = 1:pp_omega
    for j=1:pp_rho
        if abs(imag(Fimpeval_p(i,j)))>0
            if(abs(imag(Fimpeval_p(i,j)))<delta)
                Fimpeval_p(i,j) = real(Fimpeval_p(i,j));
            else
                Fimpeval_p(i,j) = NaN;
            end
        end

        if(abs(imag(Fimpeval_m(i,j)))<delta)
            Fimpeval_m(i,j) = real(Fimpeval_m(i,j));
        else
            Fimpeval_m(i,j) = NaN;
        end
    end
end

close all
handles.fig = figure;
hold on
[C1,h1] = contour(Yomega,Xrho,Fimpeval_m,[0,0],'-','LineWidth',1.5,'Color',[255/255 0/255 51/255]);
[C2,h2] = contour(Yomega,Xrho,Fimpeval_p,[0,0],'-','LineWidth',1.5,'Color',[255/255 0/255 51/255]);
axis([1.69 1.77 0 0.25])
handles.axis_handle = handles.fig.CurrentAxes;
set(handles.axis_handle,'FontSize',12)
xlabel('\Omega')
ylabel('\rho')
drawnow
Psim_a = @(rho,omega)eval(2*atan(subs(Km,epsilon,epsilon_p)));
Psip_a = @(rho,omega)eval(2*atan(subs(Kp,epsilon,epsilon_p)));

%% Plot zero-level set of G(\rho,\Omega) (including stability)

omega_sol_m_un = [];
omega_sol_m_st = [];

rho_sol_m_un = [];
rho_sol_m_st = [];

psi_sol_m_un = [];
psi_sol_m_st = [];

omega_sol_p_un = [];
omega_sol_p_st = [];

rho_sol_p_un = [];
rho_sol_p_st = [];

psi_sol_p_un = [];
psi_sol_p_st = [];

figure 
hold on
for id = 2:size(C1,2)
    
    omega_sol = C1(1,id);
    rho_sol = C1(2,id);
    psi_sol = real(Psim_a(rho_sol,omega_sol));
    
    sol_x = [rho_sol;psi_sol];
    sol_p = [omega_sol;epsilon_p];
    
    lambda_imp = eig(mech_sys_isola_dx(sol_x,sol_p));

    if real(lambda_imp(1)) > 0 || real(lambda_imp(2)) > 0 
      omega_sol_m_un = [omega_sol_m_un;omega_sol];  
      rho_sol_m_un = [rho_sol_m_un;rho_sol];  
      psi_sol_m_un = [psi_sol_m_un;psi_sol];  
      plot(omega_sol,rho_sol, '*r','MarkerSize',1)
    else
      omega_sol_m_st = [omega_sol_m_st;omega_sol];   
      rho_sol_m_st = [rho_sol_m_st;rho_sol]; 
      psi_sol_m_st = [psi_sol_m_st;psi_sol];  
      plot(omega_sol,rho_sol, '*b','MarkerSize',1)
    end

    set(gca,'FontSize',12)
    axis([1.69 1.77 0 0.25])
    axis square
    xlabel('\Omega')
    ylabel('\rho')
    grid on
    drawnow
end

for id = 2:size(C2,2)
    
    omega_sol = C2(1,id);
    rho_sol = C2(2,id);
    psi_sol = real(Psip_a(rho_sol,omega_sol));
    
    sol_x = [rho_sol;psi_sol];
    sol_p = [omega_sol;epsilon_p];
    
    lambda_imp = eig(mech_sys_isola_dx(sol_x,sol_p));

    if real(lambda_imp(1)) > 0 || real(lambda_imp(2)) > 0 
      omega_sol_p_un = [omega_sol_p_un;omega_sol];  
      rho_sol_p_un = [rho_sol_p_un;rho_sol]; 
      psi_sol_p_un = [psi_sol_p_un;psi_sol];  
      plot(omega_sol,rho_sol, '*r','MarkerSize',1)
    else
      omega_sol_p_st = [omega_sol_p_st;omega_sol];   
      rho_sol_p_st = [rho_sol_p_st;rho_sol];  
      psi_sol_p_st = [psi_sol_p_st;psi_sol];  
      plot(omega_sol,rho_sol, '*b','MarkerSize',1)
    end

    set(gca,'FontSize',12)
    axis([1.69 1.77 0 0.25])
    axis square
    xlabel('\Omega')
    ylabel('\rho')
    grid on
    drawnow
end

