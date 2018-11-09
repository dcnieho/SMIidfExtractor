function samp = getSampleStorage(version,dataInfo)

samp.timestamp = simpleVec();
samp.setNum    = simpleVec();

if version==9
    samp.pupConf = simpleVec();
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
        samp.(eye).rawPup = simpleVec();
    end
    % Pupil diameter
    if dataInfo.hasPupDiam
        samp.(eye).pupDiam = simpleVec();
    end
    % CRs
    for c=1:dataInfo.nCR
        samp.(eye).(sprintf('rawCR%d',c)) = simpleVec();
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
        samp.(eye).gaze = simpleVec();
    end
    % if remotes, seems to have a plane per eye. TODO: Part of
    % hasEyeball?
    if dataInfo.hasEyeball
        samp.(eye).plane = simpleVec();
    end
end
% head 6dof data
if dataInfo.hasHeadPos
    samp.headPos = simpleVec();
end
if dataInfo.hasHeadOri
    samp.headOri = simpleVec();
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
        samp.(eye).eyePos     = simpleVec();
        samp.(eye).gazeVec    = simpleVec();
    end
end