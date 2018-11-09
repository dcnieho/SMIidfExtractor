function samp = getSamples(samples,version,dataInfo)
% get data out of simpleVecs

if nargin==1
    fs=fieldnames(samples);
    for f=1:length(fs)
        if isstruct(samples.(fs{f}))
            samp.(fs{f}) = getSamples(samples.(fs{f}));
        else
            samp.(fs{f}) = samples.(fs{f}).get();
        end
    end
    return
end

samp.timestamp = typecast(samples.timestamp.get(),'uint64');
samp.setNum    = double(typecast(samples.setNum.get(),'uint32'));

if version==9
    samp.pupConf = double(samples.pupConf.get());
elseif version==8
    % nothing
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
        samp.(eye).rawPup = reshape(typecast(samples.(eye).rawPup.get(),'double'),2,[]).';
    end
    % Pupil diameter
    if dataInfo.hasPupDiam
        samp.(eye).pupDiam = reshape(typecast(samples.(eye).pupDiam.get(),'double'),2,[]).';
    end
    % CRs
    for c=1:dataInfo.nCR
        CRlbl = sprintf('rawCR%d',c);
        samp.(eye).(CRlbl) = reshape(typecast(samples.(eye).(CRlbl).get(),'double'),2,[]).';
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
        samp.(eye).gaze = reshape(typecast(samples.(eye).gaze.get(),'double'),2,[]).';
    end
    % if remotes, seems to have a plane per eye. TODO: Part of
    % hasEyeball?
    if dataInfo.hasEyeball
        samp.(eye).plane = double(typecast(samples.(eye).plane.get(),'int32'));
    end
end
% head 6dof data
if dataInfo.hasHeadPos
    samp.headPos = reshape(typecast(samples.headPos.get(),'double'),3,[]).';
end
if dataInfo.hasHeadOri
    samp.headOri = reshape(typecast(samples.headOri.get(),'double'),3,[]).';
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
        samp.(eye).eyePos     = reshape(typecast(samples.(eye).eyePos.get(),'double'),3,[]).';
        samp.(eye).gazeVec    = reshape(typecast(samples.(eye).gazeVec.get(),'double'),3,[]).';
    end
end