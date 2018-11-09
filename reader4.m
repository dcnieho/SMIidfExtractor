clear all

switch 2
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
CRnames             = arrayfun(@(x) sprintf('rawCR%d',x), [1:dataInfo.nCR], 'uni', false);
dataInfo.hasEyeball = ismember('Eyeball',columns);  % think this is eye position and gaze vec
dataInfo.hasPOR     = all(ismember({'GX','GY'},columns));
dataInfo.hasHeadPos = all(ismember({'HX','HY','HZ'},columns));
dataInfo.hasHeadOri = all(ismember({'Ha','Hb','Hc'},columns));
dataInfo.hasTrig    = ismember('Trig',columns);

% now move forward fixed amount, 38 chars (which seems to always be
% 0000000000000000000000000000000000000000000000000100000004000000000000000000F03F)
fseek(fid,38,'cof');
% then we expect 16368 (F0 3F), which seems to be a start of data marker
assert(fread(fid, 1, 'int16')==16368)

% read samples and messages
dataStream  = streamReader(fread(fid, inf, '*uint8'));
fclose(fid);
msgs.timeStamp  = simpleVec();
msgs.msg        = simpleVec();
samples         = getSampleStorage(version,dataInfo);
subject = '';
description = '';
% single char indicates type of entry
type = dataStream.read();
while true
    if any(type=='SM')
        % % int32 indicating how many times the uint32 timestamp counter has
        % % wrapped
        % nWrap = uint64(dataStream.read('uint32',1));
        % % get timestamp, taking wrapping into account
        % timeStamp = uint64(2)^32*nWrap + uint64(dataStream.read('uint32',1));
        % simpler way (and doing all the typecast last):
        temp = dataStream.read(8);
        timeStamp = temp([5:8 1:4]);
    end
    switch char(type)
        case 'M'
            msgs.timeStamp.append(timeStamp);
            nChar = double(dataStream.read());
            msgs.msg.append({char(dataStream.read(nChar))});
            dataStream.seek(4); % 4 bytes with unknown function, skip
        case 'S'
            samples.timestamp.append(timeStamp);
            % uint32: trial number (called setNum)
            samples.setNum.append(dataStream.read(4));
            % stuff i do not know what it is, skip
            if version==9
                % seems always 10 uint8s that i don't know about (two int
                % 32 and a short?)
                dataStream.seek(10);
                % uint8: pupil confidence
                samples.pupConf.append(dataStream.read(1));
            elseif version==8
                % TODO: only have v8 files from towers, monocular. don't
                % know if it is correct there is less here than in v9
                % seems always 10 uint8s that i don't know about (two int
                % 32 and a short?)
                dataStream.seek(8);
            end
            % raw pupil CR data
            for e=1:(dataInfo.hasLeft+dataInfo.hasRight)
                % get which eye
                if (e==1 && ~dataInfo.hasLeft) || e==2
                    eye = 'R';
                else
                    eye = 'L';
                end
                % 2 doubles: raw Pupil location
                if dataInfo.hasPupRaw
                    samples.(eye).rawPup.append(dataStream.read(16));
                end
                % 2 doubles: Pupil diameter
                if dataInfo.hasPupDiam
                    samples.(eye).pupDiam.append(dataStream.read(16));
                end
                % 2 doubles per CR
                for c=1:dataInfo.nCR
                    samples.(eye).(CRnames{c}).append(dataStream.read(16));
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
                % 2 doubles: point of regard
                if dataInfo.hasPOR
                    samples.(eye).gaze.append(dataStream.read(16));
                end
                % if remotes, seems to have a plane per eye. TODO: Part of
                % hasEyeball?
                if dataInfo.hasEyeball
                    % int32: plane
                    samples.(eye).plane.append(dataStream.read(4));
                    % seems one more double of unknown use, ignore
                    dataStream.seek(8);
                end
            end
            % 3 doubles: head 6dof data, position
            if dataInfo.hasHeadPos
                samples.headPos.append(dataStream.read(24));
            end
            % 3 doubles: head 6dof data, orientation
            if dataInfo.hasHeadOri
                samples.headOri.append(dataStream.read(24));
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
                    % 3 doubles: eye position
                    samples.(eye).eyePos.append(dataStream.read(24));
                    % 3 doubles: gaze vector
                    samples.(eye).gazeVec.append(dataStream.read(24));
                    % should be approximately 1: sqrt(sum(samp.gazeVec.^2))
                end
            end
        case 'E'
            % two strings, for subject name and description, then end of
            % file
            nChar = double(dataStream.read());
            if nChar
                subject = char(dataStream.read(nChar));
            end
            nChar = double(dataStream.read());
            if nChar
                description = char(dataStream.read(nChar));
            end
    end
    % seek until next S, M or E found, or no data left
    type = dataStream.seekFor('SME');
    if isempty(type)    % ran out of data
        break;
    end
end

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
recording.msgs.timeStamp= typecast(msgs.timeStamp.get(),'uint64');
recording.msgs.msg      = msgs.timeStamp.get();
recording.samples       = getSamples(samples,version,dataInfo);