function TomographyGUI
% TomographyGUI
% MATLAB GUI for neutron tomography reconstruction and visualization.
%
% Author: Edcer Laguda
% Department of Physics and Astronomy, McMaster University
%
% Final version: TomographyGUI37
% Finalized: 2026-06-01
%
% DO NOT EDIT this final thesis version unless a revised version is
% explicitly documented.
%
% Required MATLAB toolbox:
% - Image Processing Toolbox
%
% This GUI loads attenuation-map .mat files containing Amap,
% verifies projection angles, generates sinograms, performs
% filtered backprojection reconstruction, and visualizes
% reconstructed volumes in axial, coronal, and sagittal planes.


%==================== STATE ====================
S = struct();
S.folder = pwd; S.files = string.empty(1,0);
S.ang_raw=[]; S.ang_eff=[]; S.proj={}; S.NY=[]; S.NX=[];
S.detAxis='columns'; S.flipLR=false; S.dirCW=false;
S.aOffset=0; S.centerShift=0; S.avgHalf=0; S.outN=32;
S.recon2D=[]; S.vol3D=[];
S.sliceWL=0; S.sliceWW=1;
S.muScale=1; S.muOffset=0; S.muUnits='RefHU (0=Ref, -1000=Air)'; 
S.tProj=[]; S.tBrowser=[]; S.tColor=[]; S.tMV=[];
keyAngles = [0 30 60 90 120 150];

if ~license('test','image_toolbox') && isempty(ver('images'))
    warning('TomographyGUI:MissingToolbox', ...
        'Image Processing Toolbox is required for iradon, radon, imresize, and imrect.');
end

%==================== FIGURE/TABS ====================
fig = figure('Name','Tomography GUI','NumberTitle','off',...
    'Units','pixels','Position',[40 40 1480 940],...
    'Color',[0.94 0.94 0.94],'Renderer','opengl',...
    'CloseRequestFcn',@onCloseFigure);
tg  = uitabgroup('Parent',fig,'Units','normalized','Position',[0 0 1 1]);

t1 = uitab(tg,'Title','1) File loader');     set(t1,'BackgroundColor',get(fig,'Color'));
t2 = uitab(tg,'Title','2) Key angles');       set(t2,'BackgroundColor',get(fig,'Color'));
t3 = uitab(tg,'Title','3) Tomography');       set(t3,'BackgroundColor',get(fig,'Color'));
t4 = uitab(tg,'Title','4) Axial / Coronal / Sagittal'); set(t4,'BackgroundColor',get(fig,'Color'));
t5 = uitab(tg,'Title','5) Slice browser');    set(t5,'BackgroundColor',get(fig,'Color'));
t6 = uitab(tg,'Title','6) Color browser');    set(t6,'BackgroundColor',get(fig,'Color'));

% Common margins (normalized)
PAD.top=0.09; PAD.bot=0.08; PAD.left=0.02; PAD.right=0.02;

%==================== TAB 1 ====================
mkText(t1,'Load folder of .mat (must contain "Amap")',...
    [PAD.left 1-PAD.top 0.70 0.045], 12, 'bold');
uicontrol(t1,'Style','pushbutton','String','Load folder','Units','normalized',...
    'Position',[PAD.left 1-PAD.top-0.055 0.12 0.05],'FontSize',11,'Callback',@onLoadFolder);
% Keep the status box entirely left of the preview column (which starts at 0.58)
statusX   = PAD.left + 0.13;   % where it already starts
previewX  = 0.58;              % left edge of the right preview column
gapRight  = 0.02;              % a small gap before the previews
statusW   = max(0.20, previewX - statusX - gapRight);  % auto-fit width

H.msg1 = uicontrol(t1,'Style','edit','Max',2,'Min',0,'Enable','inactive','Units','normalized', ...
    'String','No folder loaded.','Position',[statusX 1-PAD.top-0.055 statusW 0.045], ...
    'HorizontalAlignment','left','FontSize',11,'BackgroundColor',[1 1 1]);


H.tbl = uitable('Parent',t1,'Units','normalized','Position',[PAD.left 0.48 0.53 0.32],...
    'ColumnName',{'Angle (deg)','Filename'},'ColumnEditable',[false false],'FontSize',11);

axX  = 0.58;     % left edge of the preview column
axW  = 0.40;     % width of each preview axes
rowH = 0.33;     % height of each preview axes  (trimmed from 0.34)
vGap = 0.06;     % vertical gap between the two axes
yBot = 0.12;     % bottom of the lower axes
yTop = yBot + rowH + vGap;   % = 0.51 → top row spans 0.51..0.84 (below the status control)

H.axLo = axes('Parent',t1,'Units','normalized', ...
              'Position',[axX yTop axW rowH], ...
              'ActivePositionProperty','position');
axis(H.axLo,'image'); title(H.axLo,'Preview: min angle'); colormap(H.axLo,'jet'); colorbar(H.axLo);

H.axHi = axes('Parent',t1,'Units','normalized', ...
              'Position',[axX yBot axW rowH], ...
              'ActivePositionProperty','position');
axis(H.axHi,'image'); title(H.axHi,'Preview: max angle'); colormap(H.axHi,'jet'); colorbar(H.axHi);


%==================== TAB 2 ====================
mkText(t2,'Nearest to 0 / 30 / 60 / 90 / 120 / 150°',...
    [PAD.left 1-PAD.top 0.60 0.045], 12, 'bold');

H.axK = gobjects(1,6);
% --- grid for 2 rows x 3 cols, with safe vertical gap to avoid overlap ---
hGap = 0.02;                         % horizontal gap between columns
vGap = 0.05;                         % vertical gap between rows (↑ this fixes overlap)
rowH = 0.30;                         % row height (slightly smaller than 0.31)
colW = (1 - PAD.left - PAD.right - 2*hGap) / 3;

yBase = PAD.bot + 0.14;              % baseline for bottom row (above controls)
yTopRow = yBase + rowH + vGap;       % bottom of the top row

tile = @(r,c) [ ...
    PAD.left + (c-1)*(colW + hGap), ...        % x
    iff(r==1, yTopRow, yBase),       ...       % y (r=1 → top row, r=2 → bottom row)
    colW, rowH];

for k=1:6
    r=ceil(k/3); c=k-(r-1)*3;
    H.axK(k)=axes('Parent',t2,'Units','normalized','Position',tile(r,c));
    axis(H.axK(k),'image'); title(H.axK(k),sprintf('Target %d°',keyAngles(k)));
    colormap(H.axK(k),'jet'); colorbar(H.axK(k));
end
mkText(t2,'Color scaling:',[PAD.left PAD.bot 0.10 0.05],11);
H.ddScale = uicontrol(t2,'Style','popupmenu','String',{'auto (per view)','shared (1–99%)'},'Value',2,...
    'Units','normalized','Position',[PAD.left+0.11 PAD.bot+0.01 0.16 0.04],'FontSize',11,'Callback',@(~,~)refreshKeyAngles);
uicontrol(t2,'Style','pushbutton','String','Save 2×3 panel PNG','Units','normalized',...
    'Position',[PAD.left+0.28 PAD.bot+0.008 0.16 0.045],'FontSize',11,'Callback',@saveKeyPanel);
H.msg2 = mkText(t2,'Use this to sanity-check orientation, angle mapping, and 0°/180° consistency.',...
    [PAD.left PAD.bot-0.03 0.90 0.035],10);

%==================== TAB 3 ====================
% Projection viewer UP (near top) and bigger; Geometry+FBP pushed down and larger.

% --- PROJECTION VIEWER (TOP) ---
pTop = uipanel('Parent',t3,'Title','Projection viewer','Units','normalized', ...
    'Position',[PAD.left, 1-0.02-0.46, 1-PAD.left-PAD.right, 0.46]);

H.axProj = axes('Parent',pTop,'Units','normalized', ...
    'Position',[0.02 0.26 0.88 0.72], ...
    'ActivePositionProperty','position');
axis(H.axProj,'image'); colormap(H.axProj,'jet'); H.cbProj=colorbar(H.axProj);

H.sProj   = uicontrol(pTop,'Style','slider','Units','normalized', ...
    'Position',[0.02 0.18 0.88 0.06], ...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)drawProjection);

H.lblProj = mkText(pTop,'Projection: -',[0.02 0.07 0.85 0.10],11,'bold');

H.btnPlay = uicontrol(pTop,'Style','pushbutton','String','Play','Units','normalized', ...
    'Position',[0.91 0.08 0.06 0.10],'FontSize',11,'Callback',@togglePlay);

H.edFPS   = uicontrol(pTop,'Style','edit','String','12','Units','normalized', ...
    'Position',[0.97 0.08 0.03 0.10],'FontSize',11);

% --- GEOMETRY + FBP (BOTTOM) ---
pBot = uipanel('Parent',t3,'Title','Geometry + FBP','Units','normalized', ...
    'Position',[PAD.left, 0.03, 1-PAD.left-PAD.right, 0.47]);

xL=0.02; wL=0.22;
mkText(pBot,'Detector bins from:',[xL 0.90 wL 0.05],11);
H.ddAxis = pop(pBot,{'columns (X)','rows (Y)'},[xL 0.84 wL 0.06],@geomChanged);
H.chkFlip= uicontrol(pBot,'Style','checkbox','String','Flip detector (L/R)','Units','normalized', ...
    'Position',[xL 0.78 wL 0.05],'FontSize',11,'Value',0,'Callback',@geomChanged);
mkText(pBot,'Angle direction:',[xL 0.72 wL 0.05],11);
H.ddDir = pop(pBot,{'CCW (MATLAB)','CW'},[xL 0.66 wL 0.06],@geomChanged);
mkText(pBot,'Angle offset (deg):',[xL 0.60 wL 0.05],11);
H.edOff = edit(pBot,'0',[xL 0.54 0.12 0.06],@geomChanged);
mkText(pBot,'Center shift (px):',[xL 0.48 wL 0.05],11);
H.edCen = edit(pBot,'0',[xL 0.42 0.12 0.06],@geomChanged);
mkText(pBot,'Average ± rows/cols:',[xL 0.36 wL 0.05],11);
H.edHalf= edit(pBot,'0',[xL 0.30 0.12 0.06],@geomChanged);
mkText(pBot,'FBP filter:',[xL 0.24 wL 0.05],11);
H.ddFilt= pop(pBot,{'Ram-Lak','Shepp-Logan','Cosine','Hamming','Hann','None'},[xL 0.18 wL 0.06],[]);
mkText(pBot,'Output size (px):',[xL 0.12 wL 0.05],11);
H.edOut = edit(pBot,'32',[xL 0.06 0.12 0.06],@geomChanged);

% % Bigger plotting area inside pBot so the buttons don't get cut off

% --- plots smaller + clear gap to the slider and control panel ---
leftX   = 0.27;       % left edge of sinogram
midX    = 0.62;       % left edge of reconstructed slice
bottomY = 0.30;       % lower than before so it doesn't crowd the top slider
axW     = 0.31;       % a bit narrower
axH     = 0.62;       % a bit shorter → leaves air above the slider and above pCtrl

H.axSino = axes('Parent',pBot,'Units','normalized', ...
    'Position',[leftX bottomY axW axH], ...
    'ActivePositionProperty','position');
axis(H.axSino,'tight');
title(H.axSino,'Sinogram');
H.cbSino = colorbar(H.axSino);

H.axSlice = axes('Parent',pBot,'Units','normalized', ...
    'Position',[midX bottomY axW axH], ...
    'ActivePositionProperty','position');
axis(H.axSlice,'image');
title(H.axSlice,'Reconstructed slice');
H.cbSlice = colorbar(H.axSlice);

labelY  = bottomY - 0.110;   
sliderY = bottomY - 0.110;   

mkText(pBot,'Detector index (row/col):',[leftX labelY 0.20 0.04],11);
H.lblRow = mkText(pBot,'Index: -',[leftX+0.22 labelY 0.12 0.04],11,'bold');

H.sRow = uicontrol(pBot,'Style','slider','Units','normalized', ...
    'Position',[leftX sliderY 0.66 0.045], ...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)onRowChanged);

uistack(H.sRow,'top');



pCtrl = uipanel('Parent',pBot,'Title','Reconstruction & Calibration','Units','normalized', ...
    'Position',[0.26 0.02 0.72 0.16]);
H.btnBuildSino = push(pCtrl,'Build sinogram + slice',[0.01 0.22 0.20 0.56],@(~,~)buildSlice);
H.btnValidate  = push(pCtrl,'Validate vs. sinogram',[0.22 0.22 0.20 0.56],@(~,~)validateSlice);
H.btnBuildVol  = push(pCtrl,'Build 3-D volume',[0.43 0.22 0.16 0.56],@(~,~)buildVolume);
mkText(pCtrl,'mu(ref) (absolute mu):',[0.60 0.22 0.12 0.56],11);
H.edMuRef = edit(pCtrl,'0.2',[0.72 0.30 0.06 0.40],[]);
H.btnCalibRefHU = push(pCtrl,'Calibrate RefHU (Air + Ref vial)',[0.79 0.22 0.20 0.56],@(~,~)calibRefHU);
H.btnCalibAbs   = push(pCtrl,'Calibrate mu (Air + mu(ref))',[0.79 0.22 0.20 0.56],@(~,~)calibAbs);

H.msg3 = mkText(t3,'Status: ready.',[PAD.left 0.005 0.95 0.035],11);


%==================== TAB 4 ====================
H.axAx = axes('Parent',t4,'Units','normalized','Position',[0.02 0.36 0.28 0.58]); axis(H.axAx,'image'); title(H.axAx,'Axial');   colormap(H.axAx,'gray'); H.cbAx=colorbar(H.axAx);
H.axCo = axes('Parent',t4,'Units','normalized','Position',[0.36 0.36 0.28 0.58]); axis(H.axCo,'image'); title(H.axCo,'Coronal'); colormap(H.axCo,'gray'); H.cbCo=colorbar(H.axCo);
H.axSa = axes('Parent',t4,'Units','normalized','Position',[0.70 0.36 0.28 0.58]); axis(H.axSa,'image'); title(H.axSa,'Sagittal');colormap(H.axSa,'gray'); H.cbSa=colorbar(H.axSa);
xlabel(H.axAx,'x (px)'); ylabel(H.axAx,'y (px)'); labelCB(H.cbAx,'\mu');
xlabel(H.axCo,'x (px)'); ylabel(H.axCo,'y (px)'); labelCB(H.cbCo,'\mu');
xlabel(H.axSa,'x (px)'); ylabel(H.axSa,'y (px)'); labelCB(H.cbSa,'\mu');

H.sAx = uicontrol(t4,'Style','slider','Units','normalized','Position',[0.02 0.31 0.28 0.03],...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)drawMV);
H.sCo = uicontrol(t4,'Style','slider','Units','normalized','Position',[0.36 0.31 0.28 0.03],...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)drawMV);
H.sSa = uicontrol(t4,'Style','slider','Units','normalized','Position',[0.70 0.31 0.28 0.03],...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)drawMV);

mkText(t4,'Animate view:',[0.02 0.26 0.10 0.03],11);
H.ddMV = pop(t4,{'Axial','Coronal','Sagittal'},[0.12 0.26 0.10 0.035],[]);
H.btnPlayMV = push(t4,'Play',[0.23 0.26 0.07 0.035],@togglePlayMV);
H.edFPSmv   = edit(t4,'15',[0.31 0.26 0.05 0.035],[]);
mkText(t4,'Window: auto (1–99% of volume)',[0.38 0.26 0.30 0.035],11);

%==================== TAB 5 (lowered) ====================
H.axB = axes('Parent',t5,'Units','normalized','Position',[0.02 0.26 0.76 0.58]);  % LOWER
axis(H.axB,'image'); title(H.axB,'Slice'); colormap(H.axB,'gray'); H.cbB=colorbar(H.axB);
H.sB  = uicontrol(t5,'Style','slider','Units','normalized','Position',[0.02 0.19 0.76 0.03],...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)drawBrowser);
H.ddV = pop(t5,{'Axial (Z)','Coronal (Y)','Sagittal (X)'},[0.80 0.90 0.18 0.05],@(~,~)initBrowser);
H.btnPlayB = push(t5,'Play',[0.80 0.84 0.08 0.05],@togglePlayB);
H.edFPSb   = edit(t5,'15',[0.89 0.84 0.08 0.05],[]);
mkText(t5,'Window: auto (1–99% of volume)',[0.02 0.13 0.30 0.04],11);

%==================== TAB 6 (lowered) ====================
H.axC = axes('Parent',t6,'Units','normalized','Position',[0.02 0.26 0.76 0.58]);  % LOWER
axis(H.axC,'image'); title(H.axC,'Slice (Color)'); colormap(H.axC,'jet'); H.cbC=colorbar(H.axC);
H.sC  = uicontrol(t6,'Style','slider','Units','normalized','Position',[0.02 0.19 0.76 0.03],...
    'Min',1,'Max',2,'Value',1,'Callback',@(~,~)drawColorBrowser);
mkText(t6,'Scaling',[0.80 0.90 0.08 0.05],11);
H.ddVC = pop(t6,{'Axial (Z)','Coronal (Y)','Sagittal (X)'},[0.80 0.84 0.18 0.05],@(~,~)initColorBrowser);
H.ddColorScale = pop(t6,{'auto (slice)','shared (1–99% vol)'},[0.80 0.78 0.18 0.05],@(~,~)drawColorBrowser);
H.btnPlayC = push(t6,'Play',[0.80 0.72 0.08 0.05],@togglePlayC);
H.edFPSc   = edit(t6,'15',[0.89 0.72 0.08 0.05],[]);

% image handles
H.imProj=[]; H.imSino=[]; H.imSlice=[]; H.imAx=[]; H.imCo=[]; H.imSa=[]; H.imB=[]; H.imC=[];

%==================== CALLBACKS ====================
    function onLoadFolder(~,~)
        d=uigetdir(S.folder,'Select folder'); if isequal(d,0), return; end
        S.folder=d; F=dir(fullfile(d,'*.mat'));
        files=string.empty(1,0); ang=[]; proj={};
        for k=1:numel(F)
            fn=fullfile(d,F(k).name);
            if ~ismember('Amap',who('-file',fn)), continue; end
            A=load(fn,'Amap'); M=double(A.Amap); M(~isfinite(M))=0;
            a=parseAngle(F(k).name); if isnan(a), continue; end
            files(end+1)=string(F(k).name); ang(end+1)=a; proj{end+1}=M;
        end
        if isempty(files), set(H.msg1,'String','No usable files.'); return; end
        [ang,ix]=sort(ang); files=files(ix); proj=proj(ix);
        ny=min(cellfun(@(m)size(m,1),proj)); nx=min(cellfun(@(m)size(m,2),proj));
        for i=1:numel(proj), proj{i}=centerCrop(proj{i},ny,nx); end
        S.files=files; S.ang_raw=ang; S.proj=proj; S.NY=ny; S.NX=nx;
        computeEffAngles();
        set(H.tbl,'Data',[num2cell(S.ang_raw(:)) cellstr(S.files(:))]);
        set(H.msg1,'String',sprintf('Loaded %d projections; size %dx%d',numel(files),ny,nx));
        showImage(H.axLo, orientDisplay(proj{1}), 'imLo');  set(H.axLo,'CLimMode','auto');  title(H.axLo,sprintf('%.1f°',ang(1)));
        showImage(H.axHi, orientDisplay(proj{end}), 'imHi'); set(H.axHi,'CLimMode','auto'); title(H.axHi,sprintf('%.1f°',ang(end)));
        configProjSlider(); configRowSlider(); drawProjection(); refreshKeyAngles();
        initMV(); initBrowser(); initColorBrowser(); autoWindowFromVol();
        set(H.msg3,'String','Status: projections loaded.');
    end

    function geomChanged(~,~)
        S.detAxis = iff(get(H.ddAxis,'Value')==1,'columns','rows');
        S.flipLR  = logical(get(H.chkFlip,'Value'));
        S.dirCW   = (get(H.ddDir,'Value')==2);
        S.aOffset = numOrZero(H.edOff); S.centerShift = numOrZero(H.edCen);
        S.avgHalf = max(0,round(numOrZero(H.edHalf)));
        S.outN    = max(16,round(numOrZero(H.edOut))); if S.outN==0, S.outN=32; set(H.edOut,'String','32'); end
        computeEffAngles(); configProjSlider(); configRowSlider(); drawProjection();
    end

    function drawProjection(~,~)
        if isempty(S.proj), return; end
        i = clamp(round(get(H.sProj,'Value')),1,numel(S.proj));
        showImage(H.axProj, orientDisplay(S.proj{i}), 'imProj'); set(H.axProj,'CLimMode','auto');
        set(H.lblProj,'String',sprintf('Projection %d/%d  |  Raw %.1f°  →  Eff %.1f°  |  %s',...
            i, numel(S.proj), S.ang_raw(i), S.ang_eff(i), S.files(i)));
    end

    function buildSlice(~,~)
        if isempty(S.proj), return; end
        [sino, thetaU] = buildSinogram();
        filt = filterForIRADON(getChoice(H.ddFilt));
        R = iradon(sino, thetaU, 'linear', filt, 1, S.outN);
        R = S.muScale*R + S.muOffset; S.recon2D = R;
        showImage(H.axSino, sino, 'imSino'); axis(H.axSino,'tight');
        title(H.axSino, sprintf('Sinogram (%d bins × %d angles)', size(sino,1), numel(thetaU)));
        showImage(H.axSlice, R, 'imSlice'); axis(H.axSlice,'image');
        labelCB(H.cbSlice, sprintf('\\mu (%s)', S.muUnits));
        title(H.axSlice, sprintf('Reconstructed slice (%s, %s)', getChoice(H.ddFilt), S.muUnits));
        set(H.msg3,'String','Status: slice built.');
    end

    function validateSlice(~,~)
        if isempty(S.recon2D), msgbox('Build a slice first.','Info','modal'); return; end
        [sino, thetaU] = buildSinogram();
        sino_pred = radon(S.recon2D, thetaU);
        sino_pred = imresize(sino_pred,[size(sino,1) size(sino,2)],'bilinear');
        e = sino_pred - sino; nrmse = norm(e(:))/max(norm(sino(:)),eps);
        msgbox(sprintf('Validation NRMSE vs measured sinogram: %.3g', nrmse),'Forward-projection check','modal');
    end

    function buildVolume(~,~)
        if isempty(S.proj), return; end
        set(H.msg3,'String','Status: building volume…'); drawnow;
        filtVol = filterForIRADON('Ram-Lak');
        if strcmp(S.detAxis,'columns')
            D=S.NX; Ny=S.NY; vol=zeros(D,D,Ny,'single');
            for y=1:Ny, [sino,thetaU]=buildSinogramAtIndex(y);
                vol(:,:,y)=single(iradon(sino,thetaU,'linear',filtVol,1,D));
            end
        else
            D=S.NY; Nx=S.NX; vol=zeros(D,D,Nx,'single');
            for x=1:Nx, [sino,thetaU]=buildSinogramAtIndex(x);
                vol(:,:,x)=single(iradon(sino,thetaU,'linear',filtVol,1,D));
            end
        end
        S.vol3D = S.muScale*vol + S.muOffset; autoWindowFromVol();
        initMV(); initBrowser(); initColorBrowser();
        set(H.msg3,'String',sprintf('Status: volume built (%dx%dx%d).',size(vol,2),size(vol,1),size(vol,3)));
        tg.SelectedTab = t4;
    end

    function [sino, thetaU] = buildSinogram()
        idx = clamp(round(get(H.sRow,'Value')),1, max([S.NY,S.NX,2]));
        [sino, thetaU] = buildSinogramAtIndex(idx);
    end

    function [sino, thetaU] = buildSinogramAtIndex(idx)
        K=numel(S.proj);
        if strcmp(S.detAxis,'columns')
            D=S.NX; y=idx; y1=max(1,y-S.avgHalf); y2=min(S.NY,y+S.avgHalf);
            SINO=zeros(D,K);
            for k=1:K
                v = mean(S.proj{k}(y1:y2,:),1); if S.flipLR, v=fliplr(v); end
                v = applyShift1D(v, S.centerShift); SINO(:,k)=v(:);
            end
        else
            D=S.NY; x=idx; x1=max(1,x-S.avgHalf); x2=min(S.NX,x+S.avgHalf);
            SINO=zeros(D,K);
            for k=1:K
                v = mean(S.proj{k}(:,x1:x2),2); if S.flipLR, v=orientDisplay(v); end
                v = applyShift1D(v(:).', S.centerShift).'; SINO(:,k)=v(:);
            end
        end
        SINO(~isfinite(SINO))=0;
        [thetaU, SINO] = dedupeAngles(S.ang_eff, SINO);
        sino = SINO;
    end

%------------- MV / Browser / Color -------------
    function initMV(~,~)
        if isempty(S.vol3D)
            setSlider(H.sAx,1,2,1); setSlider(H.sCo,1,2,1); setSlider(H.sSa,1,2,1);
            cla(H.axAx); cla(H.axCo); cla(H.axSa); return;
        end
        setSlider(H.sAx,1,size(S.vol3D,3), round(size(S.vol3D,3)/2));
        setSlider(H.sCo,1,size(S.vol3D,1), round(size(S.vol3D,1)/2));
        setSlider(H.sSa,1,size(S.vol3D,2), round(size(S.vol3D,2)/2));
        drawMV();
    end

    function drawMV(~,~)
        if isempty(S.vol3D), return; end
        kA = clamp(round(get(H.sAx,'Value')),1,size(S.vol3D,3));
        kC = clamp(round(get(H.sCo,'Value')),1,size(S.vol3D,1));
        kS = clamp(round(get(H.sSa,'Value')),1,size(S.vol3D,2));
        IA = windowImg(double(S.vol3D(:,:,kA)), S.sliceWL, max(S.sliceWW,eps));
        IC = windowImg(double(squeeze(S.vol3D(kC,:,:))'), S.sliceWL, max(S.sliceWW,eps));
        IS = windowImg(double(squeeze(S.vol3D(:,kS,:))'), S.sliceWL, max(S.sliceWW,eps));
        showImage(H.axAx, orientDisplay(IA), 'imAx');  colormap(H.axAx,'gray');  labelCB(H.cbAx,sprintf('\\mu (%s)',S.muUnits));  title(H.axAx,'Axial');
        showImage(H.axCo, orientDisplay(IC), 'imCo');  colormap(H.axCo,'gray');  labelCB(H.cbCo,sprintf('\\mu (%s)',S.muUnits));  title(H.axCo,'Coronal');
        showImage(H.axSa, orientDisplay(IS), 'imSa');  colormap(H.axSa,'gray');  labelCB(H.cbSa,sprintf('\\mu (%s)',S.muUnits));  title(H.axSa,'Sagittal');
    end

    function initBrowser(~,~)
        if isempty(S.vol3D), setSlider(H.sB,1,2,1); cla(H.axB); return; end
        switch get(H.ddV,'Value')
            case 1, n=size(S.vol3D,3);
            case 2, n=size(S.vol3D,1);
            case 3, n=size(S.vol3D,2);
        end
        setSlider(H.sB,1,n, round(n/2)); drawBrowser();
    end
    function drawBrowser(~,~)
        if isempty(S.vol3D), return; end
        k = clamp(round(get(H.sB,'Value')), 1, round(get(H.sB,'Max')));
        switch get(H.ddV,'Value')
            case 1, M=S.vol3D(:,:,k);
            case 2, M=squeeze(S.vol3D(k,:,:))';
            case 3, M=squeeze(S.vol3D(:,k,:))';
        end
        I = windowImg(double(M), S.sliceWL, max(S.sliceWW,eps));
        showImage(H.axB, orientDisplay(I), 'imB'); labelCB(H.cbB,sprintf('\\mu (%s)',S.muUnits)); colormap(H.axB,'gray'); title(H.axB,'Slice');
    end

    function initColorBrowser(~,~)
        if isempty(S.vol3D), setSlider(H.sC,1,2,1); cla(H.axC); return; end
        switch get(H.ddVC,'Value')
            case 1, n=size(S.vol3D,3);
            case 2, n=size(S.vol3D,1);
            case 3, n=size(S.vol3D,2);
        end
        setSlider(H.sC,1,n, round(n/2)); drawColorBrowser();
    end
   function drawColorBrowser(~,~)
    if isempty(S.vol3D), return; end

    k = clamp(round(get(H.sC,'Value')), 1, round(get(H.sC,'Max')));
    switch get(H.ddVC,'Value')
        case 1, M = double(S.vol3D(:,:,k));
        case 2, M = double(squeeze(S.vol3D(k,:,:))');
        case 3, M = double(squeeze(S.vol3D(:,k,:))');
    end

    showImage(H.axC, orientDisplay(M), 'imC');

    if get(H.ddColorScale,'Value')==2
        vals = double(S.vol3D(:));
    else
        vals = M(:);
    end
    vals = vals(isfinite(vals));

    if isempty(vals)
        lo = 0; hi = 1;
    else
        lo = pct(vals,1);
        hi = pct(vals,99);
    end

    lo = max(lo, 0);

    caxis(H.axC,[lo hi]);
    labelCB(H.cbC, sprintf('mu (%s)', S.muUnits));
    colormap(H.axC,'jet');
    title(H.axC,'Slice (Color)');
   end

%------------- Calibration -------------
    function calibRefHU(~,~)
        if isempty(S.recon2D), msgbox('Build a slice first.','Info','modal'); return; end
        msgbox('RefHU: ROI #1 = AIR (background), double-click to finish.','RefHU','modal'); pause(0.1);
        h1 = imrect(H.axSlice); p1 = wait(h1); delete(h1);
        msgbox('RefHU: ROI #2 = REFERENCE vial (pure BA/Gadovist; straight).','RefHU','modal'); pause(0.1);
        h2 = imrect(H.axSlice); p2 = wait(h2); delete(h2);
        m_air = mean(pickROI(S.recon2D,p1),'all','omitnan');
        m_ref = mean(pickROI(S.recon2D,p2),'all','omitnan');
        a = -1000 / max(m_air - m_ref, eps);
        b = -a * m_ref;
        S.muScale=a; S.muOffset=b; S.muUnits='RefHU (0=Ref, -1000=Air)';
        applyAB_and_redraw(); set(H.msg3,'String','Status: scaled to RefHU.');
    end
    function calibAbs(~,~)
        if isempty(S.recon2D), msgbox('Build a slice first.','Info','modal'); return; end
        mu_ref = numOrZero(H.edMuRef); if ~isfinite(mu_ref) || mu_ref<=0, msgbox('Set μ_{ref} > 0.','Error','modal'); return; end
        msgbox('μ: ROI #1 = AIR (background).','μ','modal'); pause(0.1);
        h1 = imrect(H.axSlice); p1 = wait(h1); delete(h1);
        msgbox('μ: ROI #2 = REFERENCE vial (pure BA/Gadovist; straight).','μ','modal'); pause(0.1);
        h2 = imrect(H.axSlice); p2 = wait(h2); delete(h2);
        m_air = mean(pickROI(S.recon2D,p1),'all','omitnan');
        m_ref = mean(pickROI(S.recon2D,p2),'all','omitnan');
        a = mu_ref / max(m_ref - m_air, eps);
        b = -a * m_air;
        S.muScale=a; S.muOffset=b; S.muUnits='1/cm';
        S.recon2D = max(S.recon2D,0);  if ~isempty(S.vol3D), S.vol3D = max(S.vol3D,0); end
        applyAB_and_redraw(); set(H.msg3,'String','Status: scaled to absolute μ.');
    end

%------------- Timers -------------
        function togglePlay(~,~)
        if isempty(S.proj), return; end
        if ~isempty(S.tProj) && isvalid(S.tProj)
            stop(S.tProj); delete(S.tProj); S.tProj=[]; set(H.btnPlay,'String','Play'); return;
        end
        fps = getFPS(H.edFPS, 12, 60);   % Projections FPS edit on Tab 3
        S.tProj = timer('ExecutionMode','fixedRate', ...
                        'Period', safePeriodFromFPS(fps), ...
                        'BusyMode','drop', ...
                        'TimerFcn', @(~,~)tickProj());
        try
            start(S.tProj);
            set(H.btnPlay,'String','Pause');
        catch
            cleanupTimer('proj');
        end
    end

    function tickProj()
        try
            if isempty(S.proj) || ~ishandle(fig) || ~ishandle(H.sProj) || ~ishandle(H.axProj)
                cleanupTimer('proj'); return;
            end
            k = round(get(H.sProj,'Value'))+1; if k>round(get(H.sProj,'Max')), k=1; end
            set(H.sProj,'Value',k); drawProjection(); drawnow limitrate;
        catch, cleanupTimer('proj'); end
    end

        function togglePlayMV(~,~)
        if isempty(S.vol3D), return; end
        if ~isempty(S.tMV) && isvalid(S.tMV)
            stop(S.tMV); delete(S.tMV); S.tMV=[]; set(H.btnPlayMV,'String','Play'); return;
        end
        fps = getFPS(H.edFPSmv, 15, 60); % Multi-View FPS (Tab 4) — not H.edFPS
        S.tMV = timer('ExecutionMode','fixedRate', ...
                      'Period', safePeriodFromFPS(fps), ...
                      'BusyMode','drop', ...
                      'TimerFcn', @(~,~)tickMV());
        try
            start(S.tMV);
            set(H.btnPlayMV,'String','Pause');
        catch
            cleanupTimer('mv');
        end
    end

    function tickMV()
        try
            if isempty(S.vol3D) || ~ishandle(fig), cleanupTimer('mv'); return; end
            switch get(H.ddMV,'Value'), case 1, h=H.sAx; case 2, h=H.sCo; case 3, h=H.sSa; end
            k = round(get(h,'Value'))+1; if k>round(get(h,'Max')), k=1; end
            set(h,'Value',k); drawMV(); drawnow limitrate;
        catch, cleanupTimer('mv'); end
    end

        function togglePlayB(~,~)
        if isempty(S.vol3D), return; end
        if ~isempty(S.tBrowser) && isvalid(S.tBrowser)
            stop(S.tBrowser); delete(S.tBrowser); S.tBrowser=[]; set(H.btnPlayB,'String','Play'); return;
        end
        fps = getFPS(H.edFPSb, 15, 60);  % Slice Browser FPS (Tab 5)
        S.tBrowser = timer('ExecutionMode','fixedRate', ...
                           'Period', safePeriodFromFPS(fps), ...
                           'BusyMode','drop', ...
                           'TimerFcn', @(~,~)tickB());
        try
            start(S.tBrowser);
            set(H.btnPlayB,'String','Pause');
        catch
            cleanupTimer('browser');
        end
    end

    function tickB()
        try
            if isempty(S.vol3D) || ~ishandle(fig) || ~ishandle(H.sB) || ~ishandle(H.axB), cleanupTimer('browser'); return; end
            k = round(get(H.sB,'Value'))+1; if k>round(get(H.sB,'Max')), k=1; end
            set(H.sB,'Value',k); drawBrowser(); drawnow limitrate;
        catch, cleanupTimer('browser'); end
    end

        function togglePlayC(~,~)
        if isempty(S.vol3D), return; end
        if ~isempty(S.tColor) && isvalid(S.tColor)
            stop(S.tColor); delete(S.tColor); S.tColor=[]; set(H.btnPlayC,'String','Play'); return;
        end
        fps = getFPS(H.edFPSc, 15, 60);  % Color Browser FPS (Tab 6)
        S.tColor = timer('ExecutionMode','fixedRate', ...
                         'Period', safePeriodFromFPS(fps), ...
                         'BusyMode','drop', ...
                         'TimerFcn', @(~,~)tickC());
        try
            start(S.tColor);
            set(H.btnPlayC,'String','Pause');
        catch
            cleanupTimer('color');
        end
    end

    function tickC()
        try
            if isempty(S.vol3D) || ~ishandle(fig) || ~ishandle(H.sC) || ~ishandle(H.axC), cleanupTimer('color'); return; end
            k = round(get(H.sC,'Value'))+1; if k>round(get(H.sC,'Max')), k=1; end
            set(H.sC,'Value',k); drawColorBrowser(); drawnow limitrate;
        catch, cleanupTimer('color'); end
    end

%==================== UTILITIES ====================
    function fps = getFPS(hEdit, defaultFPS, maxFPS)
        if nargin < 2, defaultFPS = 12; end
        if nargin < 3, maxFPS = 60; end        % cap: 60 FPS is plenty for GUI
        v = round(str2double(get(hEdit,'String')));
        if ~isfinite(v) || v < 1, v = defaultFPS; end
        fps = min(max(v,1), maxFPS);
    end

    function p = safePeriodFromFPS(fps)
        p = max(0.001, 1./max(fps,1));         % >= 1 ms to silence warnings
    end

    function updateRowLabel()
        n=currentIdxCount(); n=max(2,n);
        setSlider(H.sRow,1,n,clamp(round(get(H.sRow,'Value')),1,n));
        set(H.lblRow,'String',sprintf('Index: %d  (n=%d)', round(get(H.sRow,'Value')), n));
    end
    function onRowChanged(~,~), updateRowLabel(); end
    function n=currentIdxCount()
        n = strcmp(S.detAxis,'columns')*S.NY + strcmp(S.detAxis,'rows')*S.NX;
        if n<1, n=2; end
    end
    function computeEffAngles(), sgn=iff(S.dirCW,-1,+1); S.ang_eff=mod(S.aOffset+sgn*S.ang_raw,180); refreshKeyAngles(); end
    function [thetaU,Suniq]=dedupeAngles(theta,Smat)
        [theta,ix]=sort(mod(theta(:).',180)); Smat=Smat(:,ix);
        tol=1e-7; cuts=[1 find(abs(diff(theta))>tol)+1 numel(theta)+1];
        thetaU=zeros(1,numel(cuts)-1); Suniq=zeros(size(Smat,1),numel(cuts)-1);
        for g=1:numel(cuts)-1, i1=cuts(g); i2=cuts(g+1)-1;
            thetaU(g)=mean(theta(i1:i2)); Suniq(:,g)=mean(Smat(:,i1:i2),2);
        end
    end
    function idx=nearestTo(tdeg), tgt=mod(tdeg,180); [~,idx]=min(abs(S.ang_eff(:).'-tgt)); end
    function refreshKeyAngles(~,~)
        if isempty(S.proj), return; end
        idx = arrayfun(@nearestTo,keyAngles);
        if get(H.ddScale,'Value')==2
            pool=[]; for i=idx, pool=[pool; S.proj{i}(:)]; end
            pool=pool(isfinite(pool)); if isempty(pool), lo=0; hi=1; else, lo=pct(pool,1); hi=pct(pool,99); end
        end
        for k=1:6
            im=S.proj{idx(k)}; showImage(H.axK(k),orientDisplay(im),sprintf('imK%d',k));
            colormap(H.axK(k),'jet');
            if exist('lo','var'), caxis(H.axK(k),[lo hi]); else, set(H.axK(k),'CLimMode','auto'); end
            title(H.axK(k),sprintf('Target %d°  | raw %.1f° → eff %.1f°',keyAngles(k),S.ang_raw(idx(k)),S.ang_eff(idx(k))));
        end
        set(H.msg2,'String','Use this to sanity-check orientation, angle mapping, and 0°/180° consistency.');
    end
    function autoWindowFromVol()
        if isempty(S.vol3D), S.sliceWL=0; S.sliceWW=1; return; end
        v=double(S.vol3D(:)); v=v(isfinite(v));
        if isempty(v), S.sliceWL=0; S.sliceWW=1; else, lo=pct(v,1); hi=pct(v,99); S.sliceWL=(lo+hi)/2; S.sliceWW=max(hi-lo,eps); end
    end
    function I=windowImg(M,wl,ww), lo=wl-ww/2; hi=wl+ww/2; I=(M-lo)/max(hi-lo,eps); I=min(max(I,0),1); end
    function configProjSlider(), n=max(2,numel(S.proj)); setSlider(H.sProj,1,n,clamp(round(get(H.sProj,'Value')),1,n)); end
    function configRowSlider(), n=max(2,currentIdxCount()); setSlider(H.sRow,1,n,round(n/2)); set(H.lblRow,'String',sprintf('Index: %d  (n=%d)', round(get(H.sRow,'Value')), n)); end
    function setSlider(h,minv,maxv,val), set(h,'Min',minv,'Max',maxv,'Value',clamp(val,minv,maxv)); if maxv>minv, st=max(1/(maxv-minv),0.01); set(h,'SliderStep',[st min(5*st,1)]); end, end

    function showImage(ax,M,fieldName)
        oldTitle = get(get(ax,'Title'),'String');
        needNew = true;
        if isfield(H,fieldName) && ~isempty(H.(fieldName)) && all(isgraphics(H.(fieldName),'image'))
            needNew=false;
        end
        if needNew
            H.(fieldName)=imagesc('Parent',ax,'CData',M);
            axis(ax,'image');
        else
            set(H.(fieldName),'CData',M);
        end
        set(ax,'CLimMode','auto');
        if ~isempty(oldTitle), title(ax,oldTitle); end
    end

    function applyAB_and_redraw()
        if ~isempty(S.recon2D), S.recon2D = S.muScale*S.recon2D + S.muOffset; end
        if ~isempty(S.vol3D),  S.vol3D  = S.muScale*S.vol3D  + S.muOffset;  autoWindowFromVol(); end
        if ~isempty(S.recon2D)
            showImage(H.axSlice,S.recon2D,'imSlice'); axis(H.axSlice,'image');
            labelCB(H.cbSlice,sprintf('\\mu (%s)',S.muUnits));
            title(H.axSlice,sprintf('Reconstructed slice (%s)',S.muUnits));
        end
        drawMV(); drawBrowser(); drawColorBrowser();
    end

    function a=parseAngle(fn)
        m=regexp(fn,'(\d+\.?\d*)','match'); a=NaN; if isempty(m), return; end
        v=str2double([m{:}]); v=v(isfinite(v)&v>=0&v<=360); if ~isempty(v), a=v(1); end
    end
    function M=centerCrop(M,ny,nx)
        [r,c]=size(M); sy=floor((r-ny)/2); sx=floor((c-nx)/2); M=M((1+sy):(ny+sy),(1+sx):(nx+sx));
    end
    function z=pct(x,p), x=sort(x(:)); if isempty(x), z=0; return; end, r=p/100*(numel(x)-1)+1; k=floor(r); d=r-k; if k>=numel(x), z=x(end); else, z=x(k)+d*(x(k+1)-x(k)); end
    end
    function z=clamp(x,a,b), z=max(a,min(b,x)); end
    function out=iff(c,a,b), if c, out=a; else, out=b; end, end
        function v=applyShift1D(v,sh), if ~isfinite(sh)||abs(sh)<1e-9, return; end, n=numel(v); x=1:n; v=interp1(x,v(:).',x-sh,'linear','extrap'); end


    function M = orientDisplay(M)
        % Centralized display orientation correction.
        M = flipud(M);
    end

    function labelCB(cb,str)  
        try            
            cb.Label.String = str;
        catch
            try                
                ylabel(cb,str);
            catch
            end
        end
    end
    function s=getChoice(dd), L=get(dd,'String'); s=L{get(dd,'Value')}; end
    function v=numOrZero(h), v=str2double(get(h,'String')); if ~isfinite(v), v=0; end, end
    function cleanupTimer(which)
        switch which
            case 'proj', if ~isempty(S.tProj)&&isvalid(S.tProj), stop(S.tProj); delete(S.tProj); end, S.tProj=[]; if ishandle(H.btnPlay), set(H.btnPlay,'String','Play'); end
            case 'browser', if ~isempty(S.tBrowser)&&isvalid(S.tBrowser), stop(S.tBrowser); delete(S.tBrowser); end, S.tBrowser=[]; if ishandle(H.btnPlayB), set(H.btnPlayB,'String','Play'); end
            case 'color', if ~isempty(S.tColor)&&isvalid(S.tColor), stop(S.tColor); delete(S.tColor); end, S.tColor=[]; if ishandle(H.btnPlayC), set(H.btnPlayC,'String','Play'); end
            case 'mv', if ~isempty(S.tMV)&&isvalid(S.tMV), stop(S.tMV); delete(S.tMV); end, S.tMV=[]; if ishandle(H.btnPlayMV), set(H.btnPlayMV,'String','Play'); end
        end
    end
    function onCloseFigure(~,~), cleanupTimer('proj'); cleanupTimer('browser'); cleanupTimer('color'); cleanupTimer('mv'); delete(fig); end

%==================== SMALL UI HELPERS ====================
    function h = mkText(parent,str,pos,fs,wt)
        if nargin<5, wt='normal'; end
        h = uicontrol(parent,'Style','text','String',str,'Units','normalized','Position',pos,...
            'HorizontalAlignment','left','FontSize',fs,'FontWeight',wt,'BackgroundColor',get(fig,'Color'));
    end
    function h = pop(parent,items,pos,cb)
        h = uicontrol(parent,'Style','popupmenu','Units','normalized','Position',pos,...
            'String',items,'FontSize',11); if ~isempty(cb), set(h,'Callback',cb); end
    end
    function h = edit(parent,txt,pos,cb)
        h = uicontrol(parent,'Style','edit','Units','normalized','Position',pos,'String',txt,...
            'BackgroundColor',[1 1 1],'FontSize',11); if ~isempty(cb), set(h,'Callback',cb); end
    end
    function h = push(parent,txt,pos,cb)
        h = uicontrol(parent,'Style','pushbutton','Units','normalized','Position',pos,'String',txt,...
            'FontSize',11,'Callback',cb);
    end
    function M=pickROI(im,rectPos)
        pos=round(rectPos); x1=max(1,pos(1)); y1=max(1,pos(2));
        x2=min(size(im,2),x1+pos(3)-1); y2=min(size(im,1),y1+pos(4)-1); M=im(y1:y2,x1:x2);
    end
    function filt=filterForIRADON(choice)
        s=lower(strtrim(choice));
        switch s
            case {'ram-lak','ramlak','ram lak'}, filt='Ram-Lak';
            case {'shepp-logan','shepplogan','shepp logan'}, filt='Shepp-Logan';
            case 'cosine',  filt='Cosine';
            case 'hamming', filt='Hamming';
            case 'hann',    filt='Hann';
            case {'none','no filter'}, filt='none';
            otherwise, filt='Ram-Lak';
        end
    end
end