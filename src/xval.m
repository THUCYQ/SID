function option = xval(Y, opts)
% XVAL: algorithm performs cross-validation for one lagrangian multiplier
% for the nnmf problem defined by Y,n and opts.
%
% Input:
% opts                  options to be modified by xval
% Y                     movie
% struct opts.xval:
% opts.xval.im_size     size of the std_image of Y
% opts.xval.max_iter    maximal number of iterations of the nnmf inside xval
% opts.xval.num_part    number of partitions in which the data is decomposed
% opts.xval.std_image   required; standard deviation image of Y
% opts.multiplier       string; name of the lagrangian multiplier
%                       example opts.multiplier='lamb_orth_L2'
% opts.param            paramter range of the multiplier that needs to be
%                       scanned by xval
%
% Output:
% options               output options

%%
if nargin<2
    opts=struct;
    opts.xval=struct;
end

if ~isfield(opts.xval,'im_size')
    opts.xval.im_size = 100;
end

if ~isfield(opts.xval,'max_iter')
    opts.xval.max_iter=opts.max_iter;
end

if ~isfield(opts.xval,'num_part')
    opts.xval.num_part=5;
end

if ~isfield(opts.xval,'num_part')
    opts.xval.num_part=5;
end

if ~isfield(opts.xval,'multiplier')
    opts.xval.multiplier='lamb_orth_L1';
end

switch opts.xval.multiplier
    case 'lamb_orth_L1'
        lambda = opts.lamb_orth_L1;
        disp('lamb_orth_L1');
    case 'lamb_orth_L2'
        lambda = opts.lamb_orth_L2;
        disp('lamb_orth_L2');
    case 'lamb_spat'
        lambda = opts.lamb_spat;
        disp('lamb_spat');
    case 'lamb_temp'
        lambda = opts.lamb_temp;
        disp('lamb_temp');
    case 'lamb_corr'
        lambda = opts.lamb_corr;
        disp('lamb_corr');
    case 'lamb_spat_TV'
        lambda = opts.lamb_spat_TV;
        disp('lamb_spat_TV');
    case 'lamb_temp_TV'
        lambda = opts.temp_TV;
        disp('lamb_temp_TV');
end

if ~isfield(opts.xval,'param') || isempty(opts.xval.param)
    opts.xval.param = lambda * exp(-2 * (0:4));
end

map = conv2(opts.xval.std_image.^2,ones(opts.xval.im_size+1),'valid');
[~,m] = max(map(:));
[c_x,c_y] = ind2sub(size(map),m);
[cx,cy] = meshgrid(c_y:c_y+opts.xval.im_size,c_x:c_x+opts.xval.im_size);
ind = sub2ind(size(opts.xval.std_image),cx(:),cy(:));
Y_p = Y(ind,:);

option=opts;
option.diagnostic = false;
option.max_iter=2000;
option.active = reshape(opts.active,size(opts.xval.std_image));
option.active = option.active(c_y:c_y+opts.xval.im_size,c_x:c_x+opts.xval.im_size);
[t,s] = initialize_nnmf(Y_p,opts.rank,option);
option.max_iter=opts.max_iter;
if opts.lamb_orth_L2 + opts.lamb_orth_L2
    for u=1:size(t,1)
        platz = norm(s(:,u));
        t(u,:) = t(u,:)*platz;
        s(:,u) = s(:,u)/platz;
    end
end
[N,~] = discretize([1:size(Y_p,2)],opts.xval.num_part);

for j=1:length(opts.xval.param)
    for k=1:opts.xval.num_part
        T=t(:,k~=N); S=s;
        if j==1
            yy{k}=Y_p(:,k==N);
            y{k}=Y_p(:,k~=N);
            if opts.use_std
                yy{k}=yy{k}/sqrt(sum(var(yy{k},1,2)));
                y{k}=y{k}/sqrt(sum(var(y{k},1,2)));
            else
                yy{k}=yy{k}/norm(reshape(yy{k},1,[]));
                y{k}=y{k}/norm(reshape(y{k},1,[]));
            end 
        end
        option.Y = sum(y{k},2);
        lambda = opts.xval.param(j);
        switch opts.xval.multiplier
            case 'lamb_orth_L1'
                option.lamb_orth_L1 = lambda;
            case 'lamb_orth_L2'
                option.lamb_orth_L2 = lambda;
            case 'lamb_spat'
                option.lamb_spat = lambda;
            case 'lamb_temp'
                option.lamb_temp = lambda;
            case 'lamb_corr'
                option.lamb_corr = lambda;
            case 'lamb_spat_TV'
                option.lamb_spat_TV = lambda;
            case 'lamb_temp_TV'
                option.temp_TV = lambda;
        end
        for iter=1:opts.xval.max_iter
            [S,T]=S_update(y{k},S,T,option);
            [S,T]=T_update(y{k},T,S,option);
        end
        for u=1:size(T,1)
            platz = norm(S(:,u));
            T(u,:) = T(u,:)*platz;
            S(:,u) = S(:,u)/platz;
        end
        T(isnan(T))=0;
        S(isnan(S))=0;
        T = LS_nnls(S,yy{k},option);
        if opts.use_std
            E(k) = sqrt(sum(var(S*T-yy{k},1,2),1));
        else
            E(k) = norm(reshape(S*T-yy{k},1,[]));
        end
    end
    disp(j);
    E_(j) = mean(E);
    disp(E_(j));
end
[~,n_] = min(E_);

option = opts;
switch opts.xval.multiplier
    case 'lamb_orth_L1'
        option.lamb_orth_L1 = option.lamb_orth_L1*exp(-2*(n_-1));
        disp(option.lamb_orth_L1);
    case 'lamb_orth_L2'
        option.lamb_orth_L2 = option.lamb_orth_L2*exp(-2*(n_-1));
        disp(option.lamb_orth_L2);
    case 'lamb_spat'
        option.lamb_spat = option.lamb_spat*exp(-2*(n_-1));
        disp(option.lamb_spat);
    case 'lamb_temp'
        option.lamb_temp = option.lamb_temp*exp(-2*(n_-1));
        disp(option.lamb_temp);
    case 'lamb_corr'
        option.lamb_corr = option.lamb_corr*exp(-2*(n_-1));
        disp(option.lamb_corr);
    case 'lamb_spat_TV'
        option.lamb_spat_TV = option.lamb_spat_TV*exp(-2*(n_-1));
        disp(option.lamb_spat_TV);
    case 'lamb_temp_TV'
        option.lamb_temp_TV =  option.lamb_temp_TV*exp(-2*(n_-1));
        disp(option.lamb_temp_TV);
end

figure(5);title('Generalization error');plot(opts.xval.param,E_)
drawnow expose
end