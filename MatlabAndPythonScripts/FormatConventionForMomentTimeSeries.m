% ** Explanation about the file format: **
%
% 1. dimension = wind, 2. dimension = hs, 3. dimension = tp
M(1,3,4,:) = 'Response time series (as a double vector)';
% v(1), hs(3), tp(hs(3), 4)
% v = 1, hs = 5, tp = 13.4889


v = [1:2:25, 26, 30, 35, 40, 45];
hs = [1:2:15];
y = @(x) x.^a;

% S_p = (2 pi H_s) / (g T_p^2)
% --> tp = sqrt(2 * pi * hs / (g * s_p))
tp1 = @(hs) sqrt(2 * pi * hs / (9.81 * 1/15));
tp2 = @(hs) sqrt(2 * pi * hs / (9.81 * 1/20));
tp3 = @(hs) sqrt(2 * pi * hs / (9.81 * 1/20)) + 1 ./ (1 + sqrt(hs + 2)) * 8;
tp4 = @(hs) sqrt(2 * pi * hs / (9.81 * 1/20)) + 1 ./ (1 + sqrt(hs + 2)) * 20;
tp = @(hs, idx) (idx == 1) .* tp1(hs) + (idx == 2) .* tp2(hs) + (idx ==3) .* tp3(hs) + (idx ==4) .* tp4(hs);

% ** End of explanation. **

tpMat = zeros(numel(hs),4);
tpMat(:,1)=round(tp1(hs),2);
tpMat(:,2)=round(tp2(hs),2);
tpMat(:,3)=round(tp3(hs),2);
tpMat(:,4)=round(tp4(hs),2);

% Cell arrays

Flp1 = cell(18,8,32);
Flp2 = cell(18,8,32);
Flp3 = cell(18,8,32);

Edg1 = cell(18,8,32);
Edg2 = cell(18,8,32);
Edg3 = cell(18,8,32);

Ovr = cell(18,8,32);

% Environmental conditions

windspeed = 5;
waveheigth = 1;
period = 3.10;         % 2 digits behind the comma                               
idx = 1;

filename = '1_5_1_3-1.out';

a = find(v == windspeed);
b = find(hs == waveheigth);
c = find(tpMat == period);
 


if exist ('DataEmulator.mat')
    load 'DataEmulator.mat';
else 
    warningMessage = sprintf('Warning: File does not exist or path is incorrect');
    uiwait(msgbox(warningMessage));
end

% Load file

startRow = 2406;
endRow = 290406;

formatSpec = '%11s%*11*s%*11*s%*11s%11s%11s%11s%11s%10s%12s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*10*s%*12*s%*11*s%*11*s%*10*s%*12*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11*s%*11s%11s%s%[^\n\r]';

fileID = fopen(filename,'r');

textscan(fileID, '%[^\n\r]', startRow-1, 'WhiteSpace', '', 'ReturnOnError', false);
dataArray = textscan(fileID, formatSpec, endRow-startRow+1, 'Delimiter', '', 'WhiteSpace', '', 'TextType', 'string', 'ReturnOnError', false, 'EndOfLine', '\r\n');

fclose(fileID);

raw = repmat({''},length(dataArray{1}),length(dataArray)-1);
for col=1:length(dataArray)-1
    raw(1:length(dataArray{col}),col) = mat2cell(dataArray{col}, ones(length(dataArray{col}), 1));
end
numericData = NaN(size(dataArray{1},1),size(dataArray,2));

for col=[1,2,3,4,5,6,7,8,9]
    % Converts text in the input cell array to numbers. Replaced non-numeric
    % text with NaN.
    rawData = dataArray{col};
    for row=1:size(rawData, 1)
        % Create a regular expression to detect and remove non-numeric prefixes and
        % suffixes.
        regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
        try
            result = regexp(rawData(row), regexstr, 'names');
            numbers = result.numbers;
            
            % Detected commas in non-thousand locations.
            invalidThousandsSeparator = false;
            if numbers.contains(',')
                thousandsRegExp = '^[-/+]*\d+?(\,\d{3})*\.{0,1}\d*$';
                if isempty(regexp(numbers, thousandsRegExp, 'once'))
                    numbers = NaN;
                    invalidThousandsSeparator = true;
                end
            end
            % Convert numeric text to numbers.
            if ~invalidThousandsSeparator
                numbers = textscan(char(strrep(numbers, ',', '')), '%f');
                numericData(row, col) = numbers{1};
                raw{row, col} = numbers{1};
            end
        catch
            raw{row, col} = rawData{row};
        end
    end
end

R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),raw); % Find non-numeric cells
raw(R) = {NaN}; % Replace non-numeric cells

Time = cell2mat(raw(:, 1));
RootMFlp1 = cell2mat(raw(:, 2));
RootMFlp2 = cell2mat(raw(:, 3));
RootMFlp3 = cell2mat(raw(:, 4));
RootMEdg1 = cell2mat(raw(:, 5));
RootMEdg2 = cell2mat(raw(:, 6));
RootMEdg3 = cell2mat(raw(:, 7));
ReactMXss = cell2mat(raw(:, 8));
ReactMYss = cell2mat(raw(:, 9));

clearvars filename startRow endRow formatSpec fileID dataArray ans raw col numericData rawData row regexstr result numbers invalidThousandsSeparator thousandsRegExp R;

% Calculate Ovrturning Moment

ovrM = sqrt(ReactMXss.^2 + ReactMYss.^2);

% 1. dimension = wind, 2. dimension = hs, 3. dimension = tp (digits before
% the comma)

 Flp1{a,b,c}=RootMFlp1; 
 Flp2{a,b,c}=RootMFlp2; 
 Flp3{a,b,c}=RootMFlp3; 
 
 Edg1{a,b,c}=RootMEdg1; 
 Edg2{a,b,c}=RootMEdg2; 
 Edg3{a,b,c}=RootMEdg3;
 
 Ovr{a,b,c}=ovrM;


save('DataEmulator.mat','Flp1','Flp2','Flp3','Edg1','Edg2','Edg3','Ovr', 'Time');