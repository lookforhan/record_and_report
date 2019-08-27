classdef epanet_add_damage < handle
    properties
        Epanet
    end
    properties
        K
        AreaLeak
        mu = 0.6
        C = 4427;
        Prefix_R1 = 'R1-'
        Prefix_R2 = 'R2-'
        Prefix_P1 = 'P1-'
        Prefix_P2 = 'P2-'
        Prefix_P3 = 'P3-'
        Prefix_P4 = 'P4-'
        Prefix_E1 = 'E1-'
        Prefix_E2 = 'E2-'
        Prefix_N1 = 'N1-'
        Prefix_N2 = 'N2-'
        LengthDefault = 0.01;
        DiameterDefault = 999;
        RoughnessCoeffDefault = 140;
    end
    properties
        FromNodeNameID = []
        ToNodeNameID =[]
        NewNode = []
        NewFromPipe = []
        NewToPipe = []
        PipeNameID = []
    end
    methods
        function obj = epanet_add_damage(varargin)
            switch nargin
                case 1
                    obj.Epanet = epanet(varargin{1});
                    %                 obj.Epanet = epanet(varargin{1},'BIN');
                case 2
                    obj.Epanet = epanet(varargin{1},varargin{2});
                case 3
                    obj.Epanet = epanet(varargin{1},varargin{2},varargin{3});
            end
        end
        function delete(obj)
            obj.Epanet.unload
        end
    end
    methods
        function add_break(obj,pipeID,rateLength)
            % 1. retrieve the pipe index by pipeID;
            % 2. retrieve the pipe diameter, roughnessCoeff and length by pipe index;
            % 3. calculate the parameter need for adding damage information;
            % 3.1 retrieve the fromNode of the pipe;
            % 3.2 retrieve the toNode of the pipe;
            % 3.3 retrieve the elevation of the fromNode and toNode;
            % 3.4 Retrieve the coordination of the fromNode and toNode;
            if numel(pipeID)~=numel(rateLength)
                whos('pipeID')
                whos('rateLength')
                disp('error: the pipeID and rate are discordant!')
                return
            end
            obj.PipeNameID = pipeID;

            pipeIndex = obj.Epanet.getLinkIndex(pipeID);
            % pipeDiametersAll = obj.Epanet.getLinkDiameter; % Retrieves the value of all link diameters;
            % pipeDiameter = pipeDiameter(pipeIndex);
            pipeDiameter = obj.Epanet.getLinkDiameter(pipeIndex); % pipeIndex must be 1*n format;
            pipeLengths = obj.Epanet.getLinkLength(pipeIndex);
            pipeRoughnessCoeff = obj.Epanet.getLinkRoughnessCoeff(pipeIndex);
            pipeNodesIndexAll = obj.Epanet.getLinkNodesIndex; % Retrieve the Indexes of the from/to nodes of all links;
            fromNodeIndex = pipeNodesIndexAll(pipeIndex,1);
            toNodeIndex = pipeNodesIndexAll(pipeIndex,2);
            nodeElevationsAll = obj.Epanet.getNodeElevations;
            nodeCoordinatesAll = obj.Epanet.getNodeCoordinates;
            fromNodeElevation = nodeElevationsAll(fromNodeIndex);
            fromNodeCoordinationX = nodeCoordinatesAll{1}(fromNodeIndex);
            fromNodeCoordinationY = nodeCoordinatesAll{2}(fromNodeIndex);
            toNodeElevation = nodeElevationsAll(toNodeIndex);
            toNodeCoordinationX = nodeCoordinatesAll{1}(toNodeIndex);
            toNodeCoordinationY = nodeCoordinatesAll{2}(toNodeIndex);
            obj.FromNodeNameID = obj.Epanet.getNodeNameID(fromNodeIndex');
            obj.ToNodeNameID = obj.Epanet.getNodeNameID(toNodeIndex');

            obj.NewNode.elevation = (1-rateLength).*fromNodeElevation+rateLength.*toNodeElevation;
            obj.NewNode.coordinationX = (1-rateLength).*fromNodeCoordinationX+rateLength.*toNodeCoordinationX;
            obj.NewNode.coordinationY = (1-rateLength).*fromNodeCoordinationY+rateLength.*toNodeCoordinationY;

            obj.NewFromPipe.length = rateLength.*pipeLengths;
            obj.NewFromPipe.diameter = pipeDiameter;
            obj.NewFromPipe.roughnessCoeff = pipeRoughnessCoeff;

            obj.NewToPipe.length = (1-rateLength).*pipeLengths;
            obj.NewToPipe.diameter = pipeDiameter;
            obj.NewToPipe.roughnessCoeff = pipeRoughnessCoeff;
        end
        function init(obj)
            obj.FromNodeNameID = [];
            obj.ToNodeNameID =[];
            obj.NewFromPipe = [];
            obj.NewToPipe =[];
            obj.NewNode = [];
            obj.PipeNameID = [];
        end
        function saveInpFile(obj,fileName)
            obj.Epanet.saveInputFile(fileName);
        end
    end
    methods
        function generateBreakModel_2R2C(obj)
            % Two reservoirs are add to simulate a break on a pipe.
            % Two pipes are add to link the two reservoirs with nodes, respectively.
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                R1_id = [obj.Prefix_R1,obj.PipeNameID{i}];
                R2_id = [obj.Prefix_R2,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];

                R1_index = obj.Epanet.addNodeReservoir(R1_id);
                obj.Epanet.setNodeCoordinates(R1_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(R1_index,obj.NewNode.elevation(i));

                R2_index = obj.Epanet.addNodeReservoir(R2_id);
                obj.Epanet.setNodeCoordinates(R2_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(R2_index,obj.NewNode.elevation(i));

                P1_index = obj.Epanet.addLinkPipeCV(P1_id,obj.FromNodeNameID{i},R1_id);
                obj.Epanet.setLinkDiameter(P1_index,obj.NewFromPipe.diameter(i));
                obj.Epanet.setLinkLength(P1_index,obj.NewFromPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P1_index,obj.NewFromPipe.roughnessCoeff(i));

                P2_index = obj.Epanet.addLinkPipeCV(P2_id,obj.ToNodeNameID{i},R2_id);
                obj.Epanet.setLinkDiameter(P2_index,obj.NewToPipe.diameter(i));
                obj.Epanet.setLinkLength(P2_index,obj.NewToPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P2_index,obj.NewToPipe.roughnessCoeff(i));
            end
            obj.closePipe;
        end
        function generateBreakModel_2R2P2C(obj)
            % Two reservoirs are added to simulate a break on a pipe.
            % Two pipes are added to link the two reservoirs with nodes, respectively.
            % Two dummy nodes are added to link the two reservoirs with
            % nodes, respectively.
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                R1_id = [obj.Prefix_R1,obj.PipeNameID{i}];
                R2_id = [obj.Prefix_R2,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];
                P3_id = [obj.Prefix_P3,obj.PipeNameID{i}];
                P4_id = [obj.Prefix_P4,obj.PipeNameID{i}];
                N1_id = [obj.Prefix_N1,obj.PipeNameID{i}];
                N2_id = [obj.Prefix_N2,obj.PipeNameID{i}];

                R1_index = obj.Epanet.addNodeReservoir(R1_id);
                obj.Epanet.setNodeCoordinates(R1_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(R1_index,obj.NewNode.elevation(i));

                R2_index = obj.Epanet.addNodeReservoir(R2_id);
                obj.Epanet.setNodeCoordinates(R2_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(R2_index,obj.NewNode.elevation(i));

                N1_index = obj.Epanet.addNodeJunction(N1_id);
                obj.Epanet.setNodeCoordinates(N1_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(N1_index,obj.NewNode.elevation(i));

                N2_index = obj.Epanet.addNodeJunction(N2_id);
                obj.Epanet.setNodeCoordinates(N2_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(N2_index,obj.NewNode.elevation(i));

                P1_index = obj.Epanet.addLinkPipe(P1_id,obj.FromNodeNameID{i},N1_id);
                obj.Epanet.setLinkDiameter(P1_index,obj.NewFromPipe.diameter(i));
                obj.Epanet.setLinkLength(P1_index,obj.NewFromPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P1_index,obj.NewFromPipe.roughnessCoeff(i));

                P2_index = obj.Epanet.addLinkPipe(P2_id,obj.ToNodeNameID{i},N2_id);
                obj.Epanet.setLinkDiameter(P2_index,obj.NewToPipe.diameter(i));
                obj.Epanet.setLinkLength(P2_index,obj.NewToPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P2_index,obj.NewToPipe.roughnessCoeff(i));

                P3_index = obj.Epanet.addLinkPipeCV(P3_id,N1_id,R1_id);
                obj.Epanet.setLinkDiameter(P3_index,obj.DiameterDefault);
                obj.Epanet.setLinkLength(P3_index,obj.LengthDefault);
                obj.Epanet.setLinkRoughnessCoeff(P3_index,obj.RoughnessCoeffDefault);

                P4_index = obj.Epanet.addLinkPipeCV(P4_id,N2_id,R2_id);
                obj.Epanet.setLinkDiameter(P4_index,obj.DiameterDefault);
                obj.Epanet.setLinkLength(P4_index,obj.LengthDefault);
                obj.Epanet.setLinkRoughnessCoeff(P4_index,obj.RoughnessCoeffDefault);
            end
            obj.closePipe;
        end
        function generateBreakModel_2E2C_A(obj)
            % Two emitters are add to simulate a break on a pipe.
            % Two pipes with "check valve" are added to link the two emitters with nodes, respectively.
            % The emitter coefficient is calculate as "C*mu*areaLeak".
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                E1_id = [obj.Prefix_E1,obj.PipeNameID{i}];
                E2_id = [obj.Prefix_E2,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];
                areaLeak = 0.25*pi*(obj.NewFromPipe.diameter(i)*0.001)^2;
                emitterCoeff = obj.C*obj.mu*areaLeak;
                E1_index = obj.Epanet.addNodeJunction(E1_id);
                obj.Epanet.setNodeCoordinates(E1_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(E1_index,obj.NewNode.elevation(i));
                obj.Epanet.setNodeEmitterCoeff(E1_index,emitterCoeff)

                E2_index = obj.Epanet.addNodeJunction(E2_id);
                obj.Epanet.setNodeCoordinates(E2_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(E2_index,obj.NewNode.elevation(i));
                obj.Epanet.setNodeEmitterCoeff(E2_index,emitterCoeff)

                P1_index = obj.Epanet.addLinkPipeCV(P1_id,obj.FromNodeNameID{i},E1_id);
                obj.Epanet.setLinkDiameter(P1_index,obj.NewFromPipe.diameter(i));
                obj.Epanet.setLinkLength(P1_index,obj.NewFromPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P1_index,obj.NewFromPipe.roughnessCoeff(i));

                P2_index = obj.Epanet.addLinkPipeCV(P2_id,obj.ToNodeNameID{i},E2_id);
                obj.Epanet.setLinkDiameter(P2_index,obj.NewToPipe.diameter(i));
                obj.Epanet.setLinkLength(P2_index,obj.NewToPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P2_index,obj.NewToPipe.roughnessCoeff(i));
            end
            obj.closePipe;
        end
        function generateBreakModel_2E2P_A(obj)
            % Two emitters are added to simualte a break on a pipe .
            % Two pipes are added to link the two emitters with nodes, respectively.
            % The emitter coefficient is calculate as "C*mu*areaLeak".
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                E1_id = [obj.Prefix_E1,obj.PipeNameID{i}];
                E2_id = [obj.Prefix_E2,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];
                areaLeak = 0.25*pi*(obj.NewFromPipe.diameter(i)*0.001)^2;
                emitterCoeff = obj.C*obj.mu*areaLeak;
                E1_index = obj.Epanet.addNodeJunction(E1_id);
                obj.Epanet.setNodeCoordinates(E1_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(E1_index,obj.NewNode.elevation(i));
                obj.Epanet.setNodeEmitterCoeff(E1_index,emitterCoeff)

                E2_index = obj.Epanet.addNodeJunction(E2_id);
                obj.Epanet.setNodeCoordinates(E2_index,[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.Epanet.setNodeElevations(E2_index,obj.NewNode.elevation(i));
                obj.Epanet.setNodeEmitterCoeff(E2_index,emitterCoeff)

                P1_index = obj.Epanet.addLinkPipe(P1_id,obj.FromNodeNameID{i},E1_id);
                obj.Epanet.setLinkDiameter(P1_index,obj.NewFromPipe.diameter(i));
                obj.Epanet.setLinkLength(P1_index,obj.NewFromPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P1_index,obj.NewFromPipe.roughnessCoeff(i));

                P2_index = obj.Epanet.addLinkPipe(P2_id,obj.ToNodeNameID{i},E2_id);
                obj.Epanet.setLinkDiameter(P2_index,obj.NewToPipe.diameter(i));
                obj.Epanet.setLinkLength(P2_index,obj.NewToPipe.length(i));
                obj.Epanet.setLinkRoughnessCoeff(P2_index,obj.NewToPipe.roughnessCoeff(i));
            end
            obj.closePipe;
        end
        function generateBreakModel_1E2C_A(obj)
            % One emitter is added to simualte a break on a pipe .
            % Two pipes with check valve are added to link the two emitters with nodes, respectively.
            % The emitter coefficient is calculate as "C*mu*areaLeak".
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                E1_id = [obj.Prefix_E1,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];
                areaLeak = 0.25*pi*(obj.NewFromPipe.diameter(i)*0.001)^2;
                emitterCoeff = obj.C*obj.mu*areaLeak;
                obj.addEmitter(E1_id,obj.NewNode.elevation(i),[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)],emitterCoeff);
                obj.addPipeCV(P1_id,obj.FromNodeNameID{i},E1_id,obj.NewFromPipe.length(i),obj.NewFromPipe.diameter(i),obj.NewFromPipe.roughnessCoeff(i));
                obj.addPipeCV(P2_id,obj.ToNodeNameID{i},E1_id,obj.NewToPipe.length(i),obj.NewToPipe.diameter(i),obj.NewToPipe.roughnessCoeff(i));
            end
            obj.closePipe;
        end
        function generateBreakModel_1E3C_A(obj)
            % One emitter is added to simualte a break on a pipe .
            % one dummy node is added to link emitter .
            % Three pipes with check valve are added to link the  emitters with nodes, respectively.
            % The emitter coefficient is calculate as "C*mu*areaLeak".
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                E1_id = [obj.Prefix_E1,obj.PipeNameID{i}];
                N1_id = [obj.Prefix_N1,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];
                P3_id = [obj.Prefix_P3,obj.PipeNameID{i}];
                areaLeak = 0.25*pi*(obj.NewFromPipe.diameter(i)*0.001)^2;
                emitterCoeff = obj.C*obj.mu*areaLeak;
                obj.addEmitter(E1_id,obj.NewNode.elevation(i),[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)],emitterCoeff);
                obj.addJunction(N1_id,obj.NewNode.elevation(i),[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.addPipeCV(P1_id,obj.FromNodeNameID{i},N1_id,obj.NewFromPipe.length(i),obj.NewFromPipe.diameter(i),obj.NewFromPipe.roughnessCoeff(i));
                obj.addPipeCV(P2_id,obj.ToNodeNameID{i},N1_id,obj.NewToPipe.length(i),obj.NewToPipe.diameter(i),obj.NewToPipe.roughnessCoeff(i));
                obj.addPipeCV(P3_id,N1_id,E1_id,obj.LengthDefault,obj.DiameterDefault,obj.RoughnessCoeffDefault);
            end
            obj.closePipe;
        end
        function generateBreakModel_1E1P2C_A(obj)
            % One emitter is added to simualte a break on a pipe .
            % one dummy node is added to link emitter .
            % Two pipes with chack valve are added to link the dummy node to existed nodes, respectively.
            % One normal pipe is added to link the dummy node to the emmiter.
            % The emitter coefficient is calculate as "C*mu*areaLeak".
            pipeNumber = numel(obj.PipeNameID);
            for i = 1:pipeNumber
                E1_id = [obj.Prefix_E1,obj.PipeNameID{i}];
                N1_id = [obj.Prefix_N1,obj.PipeNameID{i}];
                P1_id = [obj.Prefix_P1,obj.PipeNameID{i}];
                P2_id = [obj.Prefix_P2,obj.PipeNameID{i}];
                P3_id = [obj.Prefix_P3,obj.PipeNameID{i}];
                areaLeak = 0.25*pi*(obj.NewFromPipe.diameter(i)*0.001)^2;
                emitterCoeff = obj.C*obj.mu*areaLeak;
                obj.addEmitter(E1_id,obj.NewNode.elevation(i),[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)],emitterCoeff);
                obj.addJunction(N1_id,obj.NewNode.elevation(i),[obj.NewNode.coordinationX(i),obj.NewNode.coordinationY(i)]);
                obj.addPipeCV(P1_id,obj.FromNodeNameID{i},N1_id,obj.NewFromPipe.length(i),obj.NewFromPipe.diameter(i),obj.NewFromPipe.roughnessCoeff(i));
                obj.addPipeCV(P2_id,obj.ToNodeNameID{i},N1_id,obj.NewToPipe.length(i),obj.NewToPipe.diameter(i),obj.NewToPipe.roughnessCoeff(i));
                obj.addPipe(P3_id,N1_id,E1_id,obj.LengthDefault,obj.DiameterDefault,obj.RoughnessCoeffDefault);
            end
            obj.closePipe;
        end

    end
    methods
        function closePipe(obj)
            % Close pipes by the pipe name ID;
            P_index = obj.Epanet.getLinkIndex(obj.PipeNameID);
            pipeNumber = numel(P_index);
            value = zeros(pipeNumber,1);
            obj.Epanet.setLinkInitialStatus(P_index,value);
            obj.Epanet.setLinkStatus(P_index,value);
        end
        function addJunction(obj,ID,elevation,coordination)
            % add junction
            % example:
            % obj.addJunction('2',5,[2,4])
            index = obj.Epanet.addNodeJunction(ID);
            obj.Epanet.setNodeElevations(index,elevation);
            obj.Epanet.setNodeCoordinates(index,coordination);
        end
        function addEmitter(obj,ID,elevation,coordination,coefficient)
            % add junction with emitter coefficient
            % example:
            % obj.addEmitter('2',5,[2,4],7.3)
            obj.addJunction(ID,elevation,coordination);
            index = obj.Epanet.getNodeIndex(ID);
            obj.Epanet.setNodeEmitterCoeff(index,coefficient);
        end
        function addReservoir(obj,ID,elevation,coordination)
            % add reservoir
            % example:
            % obj.addReservoir('2',5,[2,4])
            index = obj.Epanet.addNodeReservoir(ID);
            obj.setNodeElevations(index,elevation);
            obj.setNodeCoordinates(index,coordination);
        end
        function addPipe(obj,ID,fromNode,toNode,length,diameter,roughnessCoeff)
            % add a normal pipe link
            % example:
            % obj.addPipe('3','1','2',100,300,130)
            index = obj.Epanet.addLinkPipe(ID,fromNode,toNode);
            obj.Epanet.setLinkLength(index,length);
            obj.Epanet.setLinkDiameter(index,diameter);
            obj.Epanet.setLinkRoughnessCoeff(index,roughnessCoeff);
        end
        function addPipeCV(obj,ID,fromNode,toNode,length,diameter,roughnessCoeff)
            % add a normal pipe with check valve
            % example:
            % obj.addPipeCV('3','1','2',100,300,130)
            index = obj.Epanet.addLinkPipeCV(ID,fromNode,toNode);
            obj.Epanet.setLinkLength(index,length);
            obj.Epanet.setLinkDiameter(index,diameter);
            obj.Epanet.setLinkRoughnessCoeff(index,roughnessCoeff);
        end
    end
end
