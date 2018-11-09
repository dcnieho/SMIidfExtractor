classdef streamReader < handle
    properties (Access = protected, Hidden = true)
        data;
        nElem;
        pointer;
        isEos = false;
    end
    methods
        function obj = streamReader(data)
            assert(isa(data,'uint8'))   % TODO: perhaps could accept anything, and convert (typecast()) to bytes, uint8
            obj.data    = data;
            obj.nElem   = length(data);
            obj.pointer = 1;
        end
        
        function value = read(obj,nElem)
            if nargin<2
                nElem = 1;
            end
            
            value = obj.getData(nElem);
        end
        
        function value = readType(obj,nElem,type)
            switch type
                case {'uint8','int8'}
                    nBytes = 1;
                case {'uint16','int16'}
                    nBytes = 2;
                case {'uint32','int32','single'}
                    nBytes = 4;
                case {'uint64','int64','double'}
                    nBytes = 8;
                otherwise
                    error('Type "%s" not supported, only "uint8", "int8", "uint16", "int16", "uint32", "int32", "uint64", "int64", "single", or "double" are allowed',type);
            end
            
            % get data from array, cast to true storage type
            value = typecast(obj.getData(nBytes*nElem),type);
        end
        
        function seek(obj,nElem)
            obj.pointer = obj.pointer+nElem;
        end
        
        function value = tell(obj)
            value = obj.pointer;
        end
        
        function val = seekFor(obj,value)
            % if value is an array searches for any of the values in the
            % array
            val = [];
            while obj.pointer<=obj.nElem
                if any(obj.data(obj.pointer)==value)
                    val = obj.data(obj.pointer);
                    obj.pointer = obj.pointer+1;
                    break;
                end
                obj.pointer = obj.pointer+1;
            end
            if obj.pointer>=obj.nElem
                obj.isEos = true;
            end
        end
        
        function state = eos(obj)
            state = obj.isEos;
        end
    end
    
    methods (Access = protected, Hidden = true)
        function value = getData(obj,nElem)
            % check what to read
            lastElem    = obj.pointer+nElem-1;
            
            % determine if running out of data
            if lastElem > obj.nElem
                obj.isEos   = true;
                value       = [];
                obj.pointer = obj.nElem+1;
                return;
            elseif lastElem == obj.nElem
                obj.isEos   = true;
            end
            
            % read data
            value       = obj.data(obj.pointer:lastElem);
            
            % increment read pointer
            obj.pointer = lastElem+1;
        end
    end
end