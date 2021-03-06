function pow_grand(cfg)
%POW_GRAND grand power average
% 1) read single subject-data and create gpow in cfg.dpow
% 2) do statistics for condition indicated by cfg.gpow.comp
% 3) plot the topoplot over time, frequency and singleplot for some electrodes
%
% CFG
%-Average
%  .nick: NICK to save files specific to each NICK
%  .log: name of the file and directory with analysis log
%  .subjall: index of the number of subjects
%
%  .dpow: directory with ERP data
%  .pow.cond: conditions to make averages
%
%  Baseline correction at the single-subject level:
%  .pow.bl: if empty, no baseline. Otherwise:
%  .pow.bl.baseline: two scalars with baseline windows
%  .pow.bl.baselinetype: type of baseline ('relchange')
%
%-Statistics
%  .gpow.comp: cells within cell (e.g. {{'cond1' 'cond2'} {'cond1'} {'cond2'}})
%        but you cannot have more than 2 conditions (it's always a t-test).
%   If empty, not statistics.
%   If stats,
%     .gpow.test.time: time limit for statistics (two scalars)
%     .gpow.test.freq: freq limit for statistics (two scalars)
%     .cluster.thr: threshold to consider clusters are erppeaks
%
%-Plot
%  .gpow.bline: two scalars indicating the time window for baseline in s
%  .gpow.chan(1).name: 'name_of_channels'
%  .gpow.chan(1).chan: cell with labels of channels of interest
%  .gpow.freq(1).name: 'name_of_frequency'
%  .gpow.freq(1).freq: two scalars with the frequency limits
%
%  .sens.layout: file with layout. It should be a mat containing 'layout'
%                If empty, it does not plot topo.
%
%  .rslt: directory images are saved into
%
% IN
%  [cfg.dpow 'pow_SUBJ_COND']: timelock analysis for single-subject
%
% OUT
%  [cfg.dpow 'pow_COND']: power analysis for all subjects
%  [cfg.dpow 'powpeak_COMP']: significant peaks in the POW for the comparison
%
% FIGURES (saved in cfg.log and, if not empty, cfg.rslt)
%  gpow_tfr_COMP_CHAN: time-frequency plot POW, for each condition, for one channel group
%  gpow_val_CHAN_FREQ: singleplot POW, all conditions, for one channel group, one frequency % TODO: does it re-write files
%  gpow_topo_COMP_FREQ: topoplot POW for each frequency, over time
%
% Part of EVENTBASED group-analysis
% see also ERP_SUBJ, ERP_GRAND, ERPSOURCE_SUBJ, ERPSOURCE_GRAND,
% POW_SUBJ, POW_GRAND, POWSOURCE_SUBJ, POWSOURCE_GRAND,
% POWCORR_SUBJ, POWCORR_GRAND, POWSTAT_SUBJ, POWSTAT_GRAND,
% CONN_SUBJ, CONN_GRAND, CONN_STAT

%---------------------------%
%-start log
output = sprintf('%s began at %s on %s\n', ...
  mfilename,  datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%-----------------------------------------------%
%-read the data
%---------------------------%
%-loop over conditions
for k = 1:numel(cfg.pow.cond)
  cond     = cfg.pow.cond{k};
  condname = regexprep(cond, '*', '');
  
  %-----------------%
  %-pow over subj
  [data outtmp] = load_subj(cfg, 'pow', cond);
  output = [output outtmp];
  if isempty(data); continue; end
  data = data(~cellfun(@isempty, data));
  data = baseline(cfg, data);
  %-----------------%
  
  %-----------------%
  %-average across subjects
  cfg1 = [];
  cfg1.keepindividual = 'yes';
  gpowall = ft_freqgrandaverage(cfg1, data{:});
  
  cfg2 = [];
  cfg2.variance = 'yes';
  gpow = ft_freqdescriptives(cfg2, gpowall);
  gpow.tscore =  gpow.powspctrm ./ gpow.powspctrmsem;
  gpow.cfg = []; % remove cfg
  %-----------------%
  
  %-----------------%
  %-save
  save([cfg.dpow 'pow_' condname], 'gpow')
  %-----------------%
  
end
clear gpow gpowall
%---------------------------%
%-----------------------------------------------%

%-----------------------------------------------%
%-stats and plots
if ~isempty(cfg.sens.layout)
  load(cfg.sens.layout, 'layout');
end

if isfield(cfg.gpow, 'comp')
  
  %-------------------------------------%
  %-loop over statistics conditions
  for t = 1:numel(cfg.gpow.comp)
    
    %---------------------------%
    %-statistics for effects of interest
    if numel(cfg.gpow.comp{t}) == 1
      
      %-----------------%
      %-compare against baseline
      cond = cfg.gpow.comp{t}{1};
      comp = regexprep(cond, '*', '');
      
      %-------%
      %-pow over subj
      [data] = load_subj(cfg, 'pow', cond);
      if isempty(data); continue; end
      data = data(~cellfun(@isempty, data));
      data = baseline(cfg, data);
      
      cfg1 = [];
      gpow{1} = ft_freqgrandaverage(cfg1, data{:});
      cfg1.keepindividual = 'yes';
      gpowall1 = ft_freqgrandaverage(cfg1, data{:});
      %-------%
      
      %-------%
      %-data to plot
      gplot = gpow{1};
      %-------%
      
      disp(comp)
      [powpeak outtmp] = reportcluster(cfg, gpowall1);
      %-----------------%
      
    else
      
      %-----------------%
      %-compare two conditions
      cond1 = cfg.gpow.comp{t}{1};
      cond2 = cfg.gpow.comp{t}{2};
      comp = [regexprep(cond1, '*', '') '_' regexprep(cond2, '*', '')];
      
      %-------%
      %-pow over subj
      [data] = load_subj(cfg, 'pow', cond1);
      if isempty(data); continue; end
      data = data(~cellfun(@isempty, data));
      data = baseline(cfg, data);
      
      cfg1 = [];
      gpow{1} = ft_timelockgrandaverage(cfg1, data{:});
      cfg1.keepindividual = 'yes';
      gpowall1 = ft_timelockgrandaverage(cfg1, data{:});
      %-------%
      
      %-------%
      %-pow over subj
      [data] = load_subj(cfg, 'pow', cond2);
      if isempty(data); continue; end
      data = data(~cellfun(@isempty, data));
      data = baseline(cfg, data);
      
      cfg1 = [];
      gpow{2} = ft_timelockgrandaverage(cfg1, data{:});
      cfg1.keepindividual = 'yes';
      gpowall2 = ft_timelockgrandaverage(cfg1, data{:});
      %-------%
      
      %-------%
      %-data for plot
      gplot = gpow{2};
      if isempty(cfg.pow.bl)
        gplot.powspctrm = log(gpow{i_cond1}.powspctrm ./ gpow{i_cond2}.powspctrm);
      else % with baseline correction, take the difference
        gplot.powspctrm = gpow{i_cond1}.powspctrm - gpow{i_cond2}.powspctrm;
      end
      %-------%
      
      disp(comp)
      [powpeak outtmp] = reportcluster(cfg, gpowall1, gpowall2);
      %-----------------%
      
    end
    
    save([cfg.dpow 'powpeak_' comp], 'powpeak')
    output = [output outtmp];
    %---------------------------%
    
    %---------------------------%
    %-loop over channels
    for c = 1:numel(cfg.gpow.chan)
      
      %-----------------%
      %-figure
      h = figure;
      set(h, 'Renderer', 'painters')
      
      %--------%
      %-options
      cfg3 = [];
      cfg3.channel = cfg.gpow.chan(c).chan;
      cfg3.zlim = 'maxabs';
      cfg3.parameter = 'powspctrm';
      ft_singleplotTFR(cfg3, gplot);
      colorbar
      
      title([comp ' ' cfg.gpow.chan(c).name], 'Interpreter', 'none')
      %--------%
      %-----------------%
      
      %-----------------%
      %-save and link
      pngname = sprintf('gpow_tfr_%s_%s', comp, cfg.gpow.chan(c).name);
      saveas(gcf, [cfg.log filesep pngname '.png'])
      close(gcf); drawnow
      
      [~, logfile] = fileparts(cfg.log);
      system(['ln ' cfg.log filesep pngname '.png ' cfg.rslt pngname '_' logfile '.png']);
      %-----------------%
      
    end
    %---------------------------%
    
    %---------------------------%
    %-topoplotTFR (loop over tests)
    if ~isempty(cfg.sens.layout)
      
      %-loop over freq
      for f = 1:numel(cfg.gpow.freq)
        
        %-----------------%
        %-figure
        h = figure;
        set(h, 'Renderer', 'painters')
        
        %--------%
        %-options
        cfg5 = [];
        cfg5.parameter = 'powspctrm';
        cfg5.layout = layout;
        
        cfg5.ylim = cfg.gpow.freq(f).freq;
        
        %-color scaling specific to each frequency band
        i_freq1 = nearest(gpow{1}.freq, cfg.gpow.freq(f).freq(1));
        i_freq2 = nearest(gpow{1}.freq, cfg.gpow.freq(f).freq(2));
        powspctrm = gplot.powspctrm(:, i_freq1:i_freq2, :);
        cfg5.zlim = [-1 1] * max(powspctrm(:));
        
        cfg5.style = 'straight';
        cfg5.marker = 'off';
        cfg5.comment = 'xlim';
        cfg5.commentpos = 'title';
        
        %-no topoplot if the data contains NaN
        onedat = squeeze(gpow{1}.powspctrm(1, i_freq1, :)); % take one example, lowest frequency
        cfg5.xlim = gpow{1}.time(~isnan(onedat));
        
        ft_topoplotER(cfg5, gplot);
        %--------%
        
        %--------%
        colorbar
        %--------%
        %-----------------%
        
        %-----------------%
        %-save and link
        pngname = sprintf('gpow_topo_%s_%s', condname, cfg.gpow.freq(f).name);
        saveas(gcf, [cfg.log filesep pngname '.png'])
        close(gcf); drawnow
        
        [~, logfile] = fileparts(cfg.log);
        system(['ln ' cfg.log filesep pngname '.png ' cfg.rslt pngname '_' logfile '.png']);
        %-----------------%
        
      end
      
    end
    %---------------------------%
    
    %---------------------------%
    %-singleplotER (multiple conditions at once)
    for c = 1:numel(cfg.gpow.chan)
      
      %-loop over freq
      for f = 1:numel(cfg.gpow.freq)
        
        %-----------------%
        %-figure
        h = figure;
        set(h, 'Renderer', 'painters')
        
        %--------%
        %-plot
        cfg4 = [];
        cfg4.channel = cfg.gpow.chan(c).chan;
        cfg4.parameter = 'powspctrm';
        cfg4.zlim = cfg.gpow.freq(f).freq;
        ft_singleplotER(cfg4, gpow{:});
        
        legend('cond1', 'cond2')
        ylabel(cfg4.parameter)
        
        title([comp ' ' cfg.gpow.chan(c).name ' ' cfg.gpow.freq(f).name], 'Interpreter', 'none')
        %--------%
        %-----------------%
        
        %-----------------%
        %-save and link
        pngname = sprintf('gpow_val_%s_%s_%s', comp, cfg.gpow.chan(c).name, cfg.gpow.freq(f).name);
        saveas(gcf, [cfg.log filesep pngname '.png'])
        close(gcf); drawnow
        
        [~, logfile] = fileparts(cfg.log);
        system(['ln ' cfg.log filesep pngname '.png ' cfg.rslt pngname '_' logfile '.png']);
        %-----------------%
        
      end
      %-----------------%
      
    end
    %---------------------------%
    
  end
  %-------------------------------------%
  
end
%-----------------------------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('%s ended at %s on %s after %s\n\n', ...
  mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%

%-----------------------------------------------%
%-apply baseline
function [data] = baseline(cfg, data)
%-load and apply baseline correction if necessary
for i = 1:numel(data)
  
  %-------%
  %-baseline correction
  if isfield(cfg.pow, 'bl') && ~isempty(cfg.pow.bl)
    cfg3 = [];
    cfg3.baseline = cfg.pow.bl.baseline;
    cfg3.baselinetype = cfg.pow.bl.baselinetype;
    data{i} = ft_freqbaseline(cfg3, data{i});
  end
  %-------%
  
end
%-----------------------------------------------%