clear all

switch 3
    case 1
        filename = 'C:\dat\projects\marcus dual VOG recording\recordings 170922\recordings\REDm\idf and export\withRED250vertsac.idf';
    case 2
        filename = 'C:\dat\projects\marcus dual VOG recording\recordings 170922\recordings\RED250\idf and export\withRED250horizsac.idf';
    case 3
        filename = 'C:\dat\data sets\reading data\2007 experiment\ET-data\Day 2\ET 4\0000104701.idf';
    case 4
        filename = 'C:\dat\data sets\reading data\2009 experiment\RecordedData\ETdata\Day2\Station3-RA\0000106305.idf';
end

fid = fopen(filename,'rb');
% nb: big endian file, so straight forward read

% file starts with an int32 indicating idf version (e.g. 8 or 9)
version = fread(fid, 1, 'int32');
assert(ismember(version,[8 9]))
% time_t (4 bytes) indicating recording time (seconds since unix epoch
% stored as int32)
unix_time = fread(fid, 1, 'int32');
unix_epoch = datenum(1970,1,1,0,0,0);
timestr = datestr(unix_time./86400 + unix_epoch);
% int32 indicating horizontal screen resolution
scrX = fread(fid, 1, 'int32');
% int32 indicating vertical screen resolution
scrY = fread(fid, 1, 'int32');

% then some part of format i do not understand. Scan until we find the
% header indicating the data in the samples, which starts with "Timestamp".
% I have figured out position of relevant info relative to that
buffer = fread(fid, 9, 'uchar');
while ~strcmpi(char(buffer.'),'timestamp')
    buffer = [buffer(2:end); fread(fid, 1, 'uchar')];
end
tStampPos = ftell(fid)-9;

% if v9 file:
% - from start of tStamp text, go back 41 bytes to _end_ of computer name
% - from start of computer name, go back a further 18 bytes to find
%   sampling fs and few other things
% if v8 file, which doesn't have computer name, sampling fs and such is
% directly 18 bytes before start of tStamp text
switch version
    case 8
        off = 18;
        computerName = '';
        osVersion    = '';
        iViewVersion = '';
        fseek(fid,tStampPos-off,'bof');
    case 9
        off = 41;
        % read backwards until we have a string of length indicated with
        % number right before it. just read 256 characters, must be enough
        % as length is a single uint8 and thus can't be longer than 255.
        % there will be three of those in a row, for computer name, os
        % version and iView version
        buffer = uint8([]);
        nFound = 0;
        fseek(fid,tStampPos-off-1,'bof');
        while true
            buffer = [fread(fid, 1, 'uchar') buffer];
            if length(buffer)>1 && buffer(1)==length(buffer)-1
                nFound = nFound+1;
                string = char(buffer(2:end));
                switch nFound
                    case 1
                        iViewVersion = string;
                    case 2
                        osVersion    = string;
                    case 3
                        computerName = string;
                        break;
                end
                buffer(:) = [];
            end
            % we're reading backward, so back two to end one in front of
            % the one we just read
            fseek(fid,-2,'cof');
        end
        % back another 18 to the other info we need
        fseek(fid,-18,'cof');
end

% read fs as isi in micro-s
isi = fread(fid, 1, 'int32');
fs  = round(1/isi*1000*1000);
% head distance (mm)
headDist = fread(fid, 1, 'int32');
% screen (stim) size horizontal (mm)
scrSzX = fread(fid, 1, 'int32');
% screen (stim) size vertical (mm)
scrSzY = fread(fid, 1, 'int32');

% now read data format specifier
fseek(fid,tStampPos-1,'bof');
nChar = fread(fid, 1, 'uchar');
dataSpec = fread(fid, nChar, '*char').';
assert(strcmpi(dataSpec(1:9),'timestamp'))
columns = strsplit(dataSpec,' ');
if isempty(columns{end})
    columns(end) = [];
end
% see what data types we have. assume i can hardcode their order if they
% are present
dataInfo.hasLeft    = ismember('LGX',columns);
dataInfo.hasRight   = ismember('RGX',columns);
columns = regexp(columns,'[^lrLR]+.*','match'); columns = unique(cat(1,columns{:}));
dataInfo.hasPupRaw  = all(ismember({'PupX','PupY'},columns));
dataInfo.hasPupDiam = all(ismember({'PupDX','PupDY'},columns));
CR=regexp(columns,'Cr(\d)X','tokens'); CR = cat(1,CR{:}); CR = cat(1,CR{:}); CR = str2double(CR);
dataInfo.nCR        = max(CR)+1;    % counts from zero
dataInfo.hasEyeball = ismember('Eyeball',columns);  % think this is eye position and gaze vec
dataInfo.hasPOR     = all(ismember({'GX','GY'},columns));
dataInfo.hasHeadPos = all(ismember({'HX','HY','HZ'},columns));
dataInfo.hasHeadOri = all(ismember({'Ha','Hb','Hc'},columns));

% now move forward fixed amount, 38 chars (which seems to always be
% 0000000000000000000000000000000000000000000000000100000004000000000000000000F03F)
fseek(fid,38,'cof');
% then we expect 16368 (F0 3F), which seems to be a start of data marker
assert(fread(fid, 1, 'int16')==16368)

% read samples and messages
msgs = simpleVec();
samples = simpleVec();
subject = '';
description = '';
% single char indicates type of entry
type = fread(fid, 1, '*char');
while true
    if any(type=='SM')
        % int32 indicating how many times the uint32 timestamp counter has
        % wrapped
        nWrap = fread(fid, 1, 'uint32');
        % get timestamp, taking wrapping into account
        timeStamp = uint64(2)^32*nWrap + fread(fid, 1, 'uint32');
    end
    switch type
        case 'M'
            nChar = fread(fid, 1, 'uchar');
            msgs.append({timeStamp,fread(fid, nChar, '*char').'});
            fseek(fid, 4, 'cof'); % unknown function, skip
        case 'S'
            samp.timeStamp = timeStamp;
            % trial number (called setNum)
            samp.setNum = fread(fid, 1, 'uint32');
            % stuff i do not know what it is, skip
            if version==9
                % seems always 10 uint8s that i don't know about (two int
                % 32 and a short?)
                fseek(fid, 10, 'cof');
                % pupil confidence
                samp.pupConf = fread(fid, 1, 'uchar');
            elseif version==8
                % TODO: only have v8 files from towers, monocular. don't
                % know if it is correct there is less here than in v9
                % seems always 10 uint8s that i don't know about (two int
                % 32 and a short?)
                fseek(fid, 8, 'cof');
            end
            % raw pupil CR data
            for e=1:(dataInfo.hasLeft+dataInfo.hasRight)
                % get which eye
                if (e==1 && ~dataInfo.hasLeft) || e==2
                    eye = 'R';
                else
                    eye = 'L';
                end
                % raw Pupil location
                if dataInfo.hasPupRaw
                    samp.(eye).rawPup = fread(fid, 2, 'double');
                end
                % Pupil diameter
                if dataInfo.hasPupDiam
                    samp.(eye).pupDiam = fread(fid, 2, 'double');
                end
                % CRs
                for c=1:dataInfo.nCR
                    samp.(eye).rawCRX(c,:) = fread(fid, 2, 'double');
                end
            end
            % POR data
            for e=1:(dataInfo.hasLeft+dataInfo.hasRight)
                % get which eye
                if (e==1 && ~dataInfo.hasLeft) || e==2
                    eye = 'R';
                else
                    eye = 'L';
                end
                % point of regard
                if dataInfo.hasPOR
                    samp.(eye).gaze = fread(fid, 2, 'double');
                end
                % if remotes, seems to have a plane per eye. TODO: Part of
                % hasEyeball?
                if dataInfo.hasEyeball
                    samp.(eye).plane = fread(fid, 1, 'int32');
                    % seems one more double of unknown use, ignore
                    fseek(fid, 8, 'cof');
                end
            end
            % head 6dof data
            if dataInfo.hasHeadPos
                samp.headPos = fread(fid, 3, 'double');
            end
            if dataInfo.hasHeadOri
                samp.headOri = fread(fid, 3, 'double');
            end
            % eye pos and gaze vec (TODO: is this because has eyeball?)
            if dataInfo.hasEyeball
                for e=1:(dataInfo.hasLeft+dataInfo.hasRight)
                    % get which eye
                    if (e==1 && ~dataInfo.hasLeft) || e==2
                        eye = 'R';
                    else
                        eye = 'L';
                    end
                    samp.(eye).eyePos   = fread(fid, 3, 'double');
                    samp.(eye).gazeVec  = fread(fid, 3, 'double');
                    % should be approximately 1: sqrt(sum([samp.(eye).gazeVecX samp.(eye).gazeVecY samp.(eye).gazeVecZ].^2))
                end
            end
            samples.append(samp);
        case 'E'
            % two strings, for subject name and description, then end of
            % file
            nChar = fread(fid, 1, 'uchar');
            if nChar
                subject = fread(fid, nChar, '*char').';
            end
            nChar = fread(fid, 1, 'uchar');
            if nChar
                description = fread(fid, nChar, '*char').';
            end
    end
    % seek until next S, M or E found
    while true && ~feof(fid)
        % single char indicates type of entry
        type = fread(fid, 1, '*char');
        if isempty(type) || any(type=='SME')
            break;
        end
    end
    if feof(fid)
        break;
    end
end
% clean up
fclose(fid);

% assemble output
recording.idfVersion    = version;
recording.datetime      = timestr;
recording.scrPix        = [scrX scrY];
recording.subject       = subject;
recording.description   = description;
recording.computerName  = computerName;
recording.osVersion     = osVersion;
recording.iViewVersion  = iViewVersion;
recording.fs            = fs;
recording.geom.headDist = headDist;
recording.geom.scrSz    = [scrSzX scrSzY];
recording.msgs          = msgs;
recording.samples       = samples;