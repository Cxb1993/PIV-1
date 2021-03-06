function [varargout] = PIV_PlotFigure(DataPath, PIVPath, varargin)
%% Parse arguments
% Input arguments:
% DataDisplay = {'None', 'Zero Fill', 'Frame', 'Stack Average', 'Stack Std', 'Video'}
% FrameNumber = Numeric value
% PIVDisplay = {'Arrows', 'Colour Coded', 'Colour Arrows'}
% ArrowScale = Numeric value
% VidRedMeth = {'Crop', 'Binning', 'None'}
% ColourBar = Boolean
% CLims = [Low, High]
% CRes = Numeric value
% DataCLims = [Low, High]
% FlowScale = Numeric value
% CBarLabel = label to apply to the colour bar

Parser = inputParser;

addParameter(Parser,'DataDisplay','Stack Average',...
    @(x) any(validatestring(x,{'None', 'Zero Fill', 'Frame', 'Stack Average', 'Stack Std', 'Video'})));
addOptional(Parser,'FrameNumber',1,@isnumeric);
addParameter(Parser,'PIVDisplay','Arrows',...
    @(x) any(validatestring(x,{'Arrows', 'Colour Coded', 'Colour Arrows'})));
addOptional(Parser,'ArrowScale',1,@isnumeric);
addParameter(Parser,'VidRedMeth','None',...
    @(x) any(validatestring(x,{'Crop', 'Binning', 'None'})));
addOptional(Parser,'ColourBar',false,@islogical);
addOptional(Parser,'CLims',[],@isnumeric);
addOptional(Parser,'CRes',1024,@isnumeric);
addOptional(Parser,'DataCLims',[],@isnumeric);
addOptional(Parser,'FlowScale',1,@isnumeric);
addOptional(Parser,'CBarLabel','',@ischar);
addOptional(Parser,'ArrowLineWidth',0.5,@isnumeric);

parse(Parser,varargin{:});

if ischar(PIVPath)
    load(PIVPath, 'x', 'y', 'u', 'v', 'Certainty', 'u_sum', 'v_sum', 'Certainty_sum', 'WindowSize', 'MaxStep')
else
    x = PIVPath.x;
    y = PIVPath.y;
    u = PIVPath.u;
    v = PIVPath.v;
    Certainty = PIVPath.Certainty;
    u_sum = PIVPath.u_sum;
    v_sum = PIVPath.v_sum;
    Certainty_sum = PIVPath.Certainty_sum;
    WindowSize = PIVPath.WindowSize;
    MaxStep = PIVPath.MaxStep;
end

%% Display
WriteVideo = false; % Do we want to write to the disk?

switch Parser.Results.DataDisplay
    case 'Video'
        for index = 1:size(DiffData,3)-1;
            figure(1)
            colormap gray
            
            switch Parser.Results.VidRedMeth % How do we get all the data into an MP4?
                case 'Crop'
                    imagesc(Data(:,:,index))
                    set(gca, 'Position', [0,0,1,1])
                    axis image
                    axis off
                    if index ~= 1
                        hold on
                        quiver(x,y,u{index} * Parser.Results.ArrowScale,v{index} * Parser.Results.ArrowScale, 0, 'g');
                        hold off
                    end
                    drawnow
                    Frame = print(gcf, '-RGBImage', '-r360');
                    Frame = Frame(:, 361:2520, :);
                    Frame = Frame(537:1624,121:2040,:);
                case 'Binning'
                    imagesc(imresize(Data(:,:,index), 0.25))
                    set(gca, 'Position', [0,0,1,1])
                    axis image
                    axis off
                    if index ~= 1
                        hold on
                        quiver(x,y,u{index} * Parser.Results.ArrowScale,v{index} * Parser.Results.ArrowScale, 0, 'g');
                        hold off
                    end
                    drawnow
                    Frame = print(gcf, '-RGBImage', '-r360');
                case 'None'
                    imagesc(Data(:,:,index))
                    set(gca, 'Position', [0.05,0.05,0.95,0.95])
                    axis image
                    axis off
                    if index ~= 1
                        hold on
                        quiver(x,y,u{index} * Parser.Results.ArrowScale,v{index} * Parser.Results.ArrowScale, 0, 'g');
                        %quiver(x,y,ArrowScale*ones(size(x{index})),ArrowScale*ones(size(y{index})), 0, 'g');
                        hold off
                    end
                    drawnow
                    Frame = print(gcf, '-RGBImage', '-r360');
            end
            switch WriteVideo
                case true
                    writeVideo(VideoHandle,Frame)
            end
        end
    otherwise
        switch Parser.Results.DataDisplay
            case 'None'
                % Don't load any data
            otherwise
                if ischar(DataPath)
                    Data = PIV_TiffRead(DataPath); % Read the data from the TIFF file
                else
                    Data = DataPath;
                end
        end
        
        switch Parser.Results.DataDisplay %{'None', 'FirstFrame', 'StackAverage', 'StackStd', 'Video'}
            case 'None'
                DataFrame = [];
            case 'Zero Fill'
                DataFrame = zeros(size(Data,1), size(Data,2));
            case 'Frame'
                DataFrame = double(Data(:,:,Parser.Results.FrameNumber));
            case 'Stack Average'
                DataFrame = mean(Data,3);
            case 'Stack Std'
                DataFrame = std(Data,3);
        end
        CertaintyThresh = 0.00001;
        for index = 1:size(Certainty_sum, 1)
            Certainty_sum(index) = Certainty_sum(index).*...
                isreal(u_sum(index)).*isreal(v_sum(index)); % Reject any situations where the vector is weird and not real.
        end
        x_sum = x(Certainty_sum>CertaintyThresh);
        y_sum = y(Certainty_sum>CertaintyThresh);
        switch Parser.Results.PIVDisplay
            case 'Arrows'
                if isempty(Parser.Results.DataCLims)
                    imagesc(DataFrame)
                else
                    imagesc(DataFrame, Parser.Results.DataCLims)
                end
                colormap gray
                set(gca, 'Position', [0.05,0.05,0.95,0.95])
                axis image
                axis off
                hold on
                quiver(x_sum,y_sum,u_sum(Certainty_sum>CertaintyThresh) .* Parser.Results.ArrowScale,...
                    v_sum(Certainty_sum>CertaintyThresh) .* Parser.Results.ArrowScale, 0, 'g', ...
                    'LineWidth', Parser.Results.ArrowLineWidth);
                hold off
            case 'Colour Arrows'
                if Parser.Results.ColourBar
                    subplot('Position',[0.05,0.05,0.75,0.95])
                end
                if isempty(Parser.Results.DataCLims)
                    imagesc(DataFrame)
                else
                    imagesc(DataFrame, Parser.Results.DataCLims)
                end
                colormap gray
                if ~Parser.Results.ColourBar
                    set(gca, 'Position', [0.05,0.05,0.95,0.95])
                end
                axis image
                axis off
                hold on
                u_sum = u_sum(Certainty_sum>CertaintyThresh);
                v_sum = v_sum(Certainty_sum>CertaintyThresh);
                VectMag = sqrt(u_sum.^2 + v_sum.^2);
                u_sum = u_sum./VectMag;
                v_sum = v_sum./VectMag;
                
                % Flow encoded as Hue (Hue range is 0 to 6, but we use 0 to 4 for clarity):
                if isempty(Parser.Results.CLims)
                    CLims = [min(VectMag),max(VectMag)];
                else
                    CLims = [Parser.Results.CLims(1),Parser.Results.CLims(2)];
                end
                Hue = min(floor((4-4.*(max(min(VectMag,CLims(2)),CLims(1))-CLims(1))./...
                    (CLims(2)-CLims(1)))*(Parser.Results.CRes/4)), Parser.Results.CRes-1)./((Parser.Results.CRes-1)/4);
                RGB = squeeze(HSVtoRGB(Hue, 1 * ones(size(Hue)), 1 * ones(size(Hue))));
                for Qndex = 1:size(x_sum,1)
                    quiver(x_sum(Qndex),y_sum(Qndex),u_sum(Qndex), v_sum(Qndex), ...
                        Parser.Results.ArrowScale, 'Color', RGB(Qndex,:), ...
                        'MaxHeadSize', 100*Parser.Results.ArrowScale, ...
                        'AutoScale', 'off', 'LineWidth', Parser.Results.ArrowLineWidth);
                end
                hold off
                if Parser.Results.ColourBar
                    subplot('Position',[0.92,0.05,0.05,0.9])
                    CMapSize = max(Parser.Results.CRes * 32, 1024);
                    Hue = (min(floor((4-4.*((1:CMapSize)-1)./(CMapSize-1))*(Parser.Results.CRes/4)), Parser.Results.CRes-1)./((Parser.Results.CRes-1)/4))';
                    CMap = HSVtoRGB(Hue, 1 * ones(size(Hue)), 1 * ones(size(Hue)));
                    imagesc(1,linspace(CLims(1).*Parser.Results.FlowScale,CLims(2).*Parser.Results.FlowScale, CMapSize),CMap)
                    set(gca,'YDir','normal')
                    set(gca, 'XTick', []);
                    if ~isempty(Parser.Results.CBarLabel)
                        ylabel(Parser.Results.CBarLabel)
                    end
                end
            case 'Colour Coded'
                Value = DataFrame;
                
                AbsFlow = zeros(ceil(size(Value)./WindowSize)+1);
                Saturation = zeros(size(AbsFlow));
                
                for index = 1:size(x_sum,1)
                    AbsFlow((y_sum(index)-1)./WindowSize(2) + 1, (x_sum(index)-1)./WindowSize(2) + 1) = sqrt(u_sum(index).^2+v_sum(index).^2);
                    Saturation((y_sum(index)-1)./WindowSize(2) + 1, (x_sum(index)-1)./WindowSize(2) + 1) = 0.5;
                end
                
                AbsFlow = imresize(AbsFlow, size(AbsFlow).*WindowSize, 'nearest');
                AbsFlow = AbsFlow(floor(WindowSize(2)/2) + (1:size(Value,1)), floor(WindowSize(1)/2) + (1:size(Value,2)));
                Saturation = imresize(Saturation, size(Saturation).*WindowSize, 'nearest');
                Saturation = Saturation(floor(WindowSize(2)/2) + (1:size(Value,1)), floor(WindowSize(1)/2) + (1:size(Value,2)));
                
                % Flow encoded as Hue (Hue range is 0 to 6, but we use 0 to 4 for clarity):
                if isempty(Parser.Results.CLims)
                    CLims = [min(AbsFlow),max(AbsFlow)];
                else
                    CLims = [Parser.Results.CLims(1),Parser.Results.CLims(2)];
                end
                Hue = min(floor((4-4.*(max(min(AbsFlow,CLims(2)),CLims(1))-CLims(1))./...
                    (CLims(2)-CLims(1)))*(Parser.Results.CRes/4)), Parser.Results.CRes-1)./((Parser.Results.CRes-1)/4);
                imshow(HSVtoRGB(Hue, Saturation, Value))
        end
end