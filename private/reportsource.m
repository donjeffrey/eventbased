function [soupeak stat output] = reportsource(cfg, gdat1, gdat2)
%REPORTSOURCE get cluster which are different from baseline, even if not significant
% The clusters to determine the main results of the analysis, for example
% to concentrate the source reconstruction
%
% For source, it only reports either positive or negative clusters. It does
% not make sense to have both (how can one TFR element be associated with
% activation and disactivation from baseline?)

%-------------------------------------%
%-check data
output = '';
nsubj = numel(gdat1.trial);

%-----------------%
%-pow or nai
if isfield(gdat1.avg, 'nai')
  param = 'nai';
  
elseif isfield(gdat1.avg, 'pow')
  param = 'pow';
  
else
  error('field in .avg. not recognized')
end
%-----------------%
%-------------------------------------%

%-------------------------------------%
%-calc clusters
cfg3 = [];
cfg3.method      = 'montecarlo';
cfg3.statistic   = 'depsamplesT';
cfg3.correctm    = 'cluster';
cfg3.clusterstatistic = cfg.clusterstatistics; % 'maxsize' or 'max' ('max' might be better for focal sources)
cfg3.numrandomization = 1e5;
cfg3.design = [ones(1,nsubj) ones(1,nsubj).*2; 1:nsubj 1:nsubj];
cfg3.ivar = 1;
cfg3.uvar = 2;
cfg3.feedback = 'etf';

cfg3.parameter = param;
cfg3.dim = gdat1.dim;

cfg3.alpha = 0.05;

%---------------------------%
%-get value for clusteralpha
if isnumeric(cfg.clusteralpha)
  
  cfg3.clusteralpha = cfg.clusteralpha;
  
elseif ischar(cfg.clusteralpha) && cfg.clusteralpha(end)=='%'
  
  %-----------------%
  %-use adaptive threshold
  ratio = sscanf(cfg.clusteralpha, '%f%%');
  ratio = 1 - ratio/100;
  
  %-------%
  %-get t-stat
  tstat = @(x) mean(x,2) ./ (std(x,[],2)) *sqrt(size(x,2));
  x1 = cat(2, gdat2.trial.pow);
  x2 = cat(2, gdat1.trial.pow);
  
  t = tstat(x2 - x1);
  t_thr = quantile(abs(t(~isnan(t))), ratio); % t-stat at the cfg.clusteralpha quantile
  %-------%
  
  %-------%
  %-threshold as p-value
  df = size(x1,2)-1;
  cfg3.clusteralpha = 2 * (1 - tcdf(t_thr, df));
  %-------%
  
  %-------%
  %-output
  outtmp = sprintf('using adaptive threshold at %s, which corresponds to t-stat % 6.4f, P-value % 10.2e\n', ...
    cfg.clusteralpha, t_thr, cfg3.clusteralpha);
  outtmp = regexprep(outtmp, '%', '%%'); % otherwise fprint gets confused for normal % sign
  output = [output outtmp];
  %-------%
  
  %-----------------%
  
end
%---------------------------%

stat = ft_sourcestatistics(cfg3, gdat1, gdat2);
%-------------------------------------%

%-------------------------------------%
%-find clusters
%-----------------%
%-if there are no clusters at all
if ~isfield(stat, 'posclusters')
  soupeak = [0 0 0];
  output = sprintf('no clusters at all in the data\n');
  stat.image = zeros(stat.dim);
  return
end
%-----------------%

%-----------------%
%-report cluster
clusterthr = .8;

%-------%
%-find out if more positive or negative
% it does not make sense to have both increase and decrease in power for
% the same frequency
if isempty(stat.posclusters)
  posneg = false;
elseif isempty(stat.negclusters)
  posneg = true;
else
  posneg = stat.posclusters(1).prob <= stat.negclusters(1).prob;
end

if posneg
  posnegtxt = 'pos';
  clusters = stat.posclusters;
  clusterslabelmat = stat.posclusterslabelmat;
else
  posnegtxt = 'neg';
  clusters = stat.negclusters;
  clusterslabelmat = stat.negclusterslabelmat;
end
%-------%

%-------%
%-report significant cluster
signcl = find([clusters.prob] < clusterthr);

for i = 1:numel(signcl)
  
  clmat = find(clusterslabelmat == i);
  pos = stat.pos(clmat,:);
  
  areas = mni2ba(pos);
  areastext = unique({areas.IBASPM116});
  
  outtmp = sprintf('    %s cluster% 3.f: P = %4.3f, size =% 5.f, [% 5.1f % 5.1f % 5.1f], %s\n', ...
    posnegtxt, i, clusters(i).prob, numel(clmat), mean(pos(:,1)), mean(pos(:,2)), mean(pos(:,3)), sprintf(' %s', areastext{:}));
  output = [output outtmp];
  
end
%-------%
%-----------------%
%-------------------------------------%

%-------------------------------------%
%-show only first source for connectivity analysis
cl = find(clusterslabelmat == 1);

if posneg
  [~, sstat] = sort(stat.stat(cl), 'descend');
else
  [~, sstat] = sort(stat.stat(cl), 'ascend');
end

if numel(sstat) <= cfg.maxvox
  selvox = cl(sstat);
else
  selvox = cl(sstat(1:cfg.maxvox));
  output = sprintf('%s     Too many voxels in main cluster (% 4.f), reduced to largest % 3.f (lowest t-stat:% 6.3f)\n', ...
    output, numel(sstat), cfg.maxvox, stat.stat(selvox(end)));
end

soupeak = stat.pos(selvox, :);
clmat = zeros(size(clusterslabelmat));
clmat(cl(sstat)) = 1; % in cluster, but not first cfg.maxvox
clmat(selvox) = 2; % largest t-score

stat.image = zeros(size(clusterslabelmat));
stat.image(selvox) = 1;
%-------------------------------------%

%-------------------------------------%
%-----------------%
%-plot main cluster
%-prepare figure
backgrnd = isnan(clusterslabelmat); % separate NaN to be used as background

%-prepare axis
xpos = unique(stat.pos(:,1));
ypos = unique(stat.pos(:,2));
zpos = unique(stat.pos(:,3));
%-----------------%

%-----------------%
%-plot
%-------%
%-x-axis
subplot(2,2,1)
[~, imax] = max(sum(sum(clmat==2,2),3));
toplot = nansum(cat(1, -1 * backgrnd(imax,:,:),  clmat(imax, :, :)), 1);

imagesc(ypos, zpos, squeeze(toplot)', [-.5 2])
axis xy equal
colormap hot

title(sprintf('x =% 3.f', xpos(imax)))
%-------%

%-------%
%-y-axis
subplot(2,2,2)
[~, imax] = max(sum(sum(clmat==2,1),3));
toplot = nansum(cat(2, -1 * backgrnd(:,imax,:),  clmat(:,imax,:)), 2);

imagesc(xpos, zpos, squeeze(toplot)', [-.5 2])
axis xy equal
colormap hot

title(sprintf('y =% 3.f', ypos(imax)))
%-------%

%-------%
%-z-axis
subplot(2,2,3)
[~, imax] = max(sum(sum(clmat==2,1),2));
toplot = nansum(cat(3, -1 * backgrnd(:,:,imax),  clmat(:,:,imax)), 3);

imagesc(xpos, ypos, squeeze(toplot)', [-.5 2])
axis xy equal
colormap hot

title(sprintf('z =% 3.f', zpos(imax)))
%-------%
%-----------------%
%-------------------------------------%
