classdef simpleVec < handle
    properties (Access = protected, Hidden = true)
        data;
        nElem=0;
    end
    methods
        function obj = simpleVec()
        end
        
        function append(obj,val)
            nIn = size(val,1);
            if obj.nElem+nIn>length(obj.data)
                % allocate more space
                if isempty(obj.data)    % no elements yet, start with enough space for input, or at least 16
                    obj.realloc(max(2^nextpow2(nIn),16),val)
                else
                    newNElem = 2^nextpow2(length(obj.data)+nIn);
                    obj.realloc(newNElem,obj.data(end,:));
                end
            end
            % put value
            obj.data(obj.nElem+1:obj.nElem+nIn,:)   = val;
            obj.nElem                               = obj.nElem+nIn;
        end
        
        function out = get(obj)
            out = obj.data(1:obj.nElem,:);
        end
        
    end
    
    methods (Access = protected, Hidden = true)
        function realloc(obj,nElem,theElem)
            % alloc new space
            if isa(theElem,'cell')
                temp = cell(nElem,size(theElem,2));
            elseif isa(theElem,'struct')
                temp = repmat(theElem,nElem,1);
            else
                temp = zeros(nElem,size(theElem,2),'like',theElem);
            end
            % copy over old values
            if obj.nElem
                temp(1:obj.nElem,:) = obj.data(1:obj.nElem,:);
            end
            % remove old
            obj.data = temp;
        end
    end
end