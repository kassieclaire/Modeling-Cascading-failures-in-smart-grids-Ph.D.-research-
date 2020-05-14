% fixed simulation for MDP: as Mahshid works (line vs r and theta is
% intuitive)
clc;
clear all;
close all;
define_constants;
CaseName='case118';
FakeCapRate = 1; % fake capacity
%% Parameter initialization
TrueCaps=[20 80 200 500 1000]; % quantized capacity
%% Initial load on which the capacity of lines will be determined
mpc1 = loadcase(CaseName);
mpc1 = S_ReadyTheCase(mpc1);
%% keep the original values of number of buses and gens and branches before changing
originalNumBus=length(mpc1.bus(:,1));
originalNumGen=length(mpc1.gen(:,1));
originalNumBran=length(mpc1.branch(:,1));
NumBuses = length(mpc1.bus(:,1));
NumBranches = originalNumBran;
%% Seperate the buses with both load and generators into seperate load and generator buses
[mpc1 LoadGenMatch] = S_SeperateGenAndLoad(mpc1);
%%%% Calculating the total demand and generation capacity of the grid%%%%%
% In the case of IEEE 118 topology 6.9 corresponds to using the full
% generation capacity of the grid (not sure what this means?)
[WhichInitialLoad, Generation, Demand, DemandIndex]=S_FindFullLoadOfGrid(mpc1);

%WhichInitialLoad = 0.2537
clear mpc1; % clear because
mpc1 = loadcase(CaseName);
mpc1 = S_ReadyTheCase(mpc1);
%% check if any negative load
for i=1:NumBuses
    if (mpc1.bus(i,3)<0) % if the real power of the bus is negative
        mpc1.bus(i,3) = abs(mpc1.bus(i,3));
    end
end
%% Seperate the buses with both load and generators into seperate load and generator buses
[mpc1 LoadGenMatch] = S_SeperateGenAndLoad(mpc1);
%% Find installed capacity of a transmission line and use it as rateA threshold
Capacity = S_CapFinder(WhichInitialLoad,mpc1,TrueCaps,originalNumBran);
mpc1.branch(:,6) = FakeCapRate*Capacity;

CountCaps=zeros(1,length(TrueCaps));
for i=1:length(TrueCaps)
    CountCaps(i)=sum(Capacity==TrueCaps(i));
end
%mpc1.gencost
%% Reset mpc1, PD: take mpc with separated load and generator
OriginalMPC = mpc1; % this is the MPC with separated load and generator
clear mpc1;
%% initialize parameters
DGRatioVector = 0.1; % r
DeltaVector = 0; % e
NoCoopPercentageVector = 0.1; % theta
alpha = DeltaVector;
DGRatio = DGRatioVector;
NoCoopPercentage = NoCoopPercentageVector;
%% Generate an initial failure table
%{
iniFailNodes = [];
for i=1:NumIt
    %2 or 3 failures
    b=1+ceil(2*rand);
    b=8;
    randomindex=randperm(NumBranches);
    temp=randomindex(1:b);
    iniFailNodes = [iniFailNodes;temp];
    IniFidx=randomindex(1:b);
    %IniFidx = [136 119];
    %IniFidx=[65];
    IniFtable{1,i} = IniFidx;
    clear IniFidx
end
%}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mpc1 = OriginalMPC; % this is the MPC with separated load and generator
BranchMatrix=mpc1.branch;
NumBranches=length(BranchMatrix(:,1));
BusMatrix=mpc1.bus;
NumBuses=length(BusMatrix(:,1));
GenMatrix=mpc1.gen;
NumGens=length(GenMatrix(:,1));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

NumIt = 1; % Number of iteration for extracting states.
% Load the optimal policy
%MDP_pol = load('MDP_Policy.mat');
%opt_pol = MDP_pol.aStarRow_fut;
%theta_vector = [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9];
%theta_vector = [0.11 0.29 0.5 0.7];
theta_vector =  0.1;
%theta_vector = [0.1];
%DGRatioVector = [0.15 0.3 0.45 0.65 0.85];
%DGRatioVector = [0.39 0.69 0.89];
DGRatioVector = 0.6;
DeltaVector = 0.1; % e
alpha = DeltaVector;
theta_idx = 1;
for theta = theta_vector
    NoCoopPercentage = theta;
    r_idx = 1;
    for DGRatio = DGRatioVector
        %DGRatio;
        load_shed = 0;
        failed_line = 0;
        served_load = 0;
        generated = 0;
        cascade_stop_time = 0;
        StateCounter = 0; %counts the number of possible states
        clear States;
        limit = 100000;
        States = zeros(limit,13);
        tic
        for s=1:NumIt % for every iteration
            if StateCounter > limit * 0.99
                break;
            end        
            TotalShed = 0;
            ListOfFailures=zeros(1,NumBranches); % List of failures in one scenario of cascade
            mpc1 = OriginalMPC;  % this is the MPC with separated load and generator
            BranchMatrix=mpc1.branch;
            BusMatrix=mpc1.bus;
            GenMatrix=mpc1.gen;
            NumBranches=length(BranchMatrix(:,1));
            NumBuses=length(BusMatrix(:,1));
            NumGens=length(GenMatrix(:,1));
            % adjoint matrix
            AdjMatrix = zeros(NumBuses,NumBuses);
            for j=1:NumBranches
                AdjMatrix(mpc1.branch(j,1),mpc1.branch(j,2))=1;
                AdjMatrix(mpc1.branch(j,2),mpc1.branch(j,1))=1;
            end
            %% Set the load over the grid to according to the DGRatio (use of r)
            Demand = 0;
            for i=1:length(mpc1.bus(:,1))
                if(mpc1.bus(i,2)==1) % if it is a load bus
                    mpc1.bus(i,3)=mpc1.bus(i,3)*DGRatio*WhichInitialLoad;
                    Demand = Demand + mpc1.bus(i,3); % by PD
                    busDemand(i) = mpc1.bus(i,3); % by PD
                end
            end
            %mpc1.bus(:,3)'
            % end of r section
            %% use of \theta
            LSCooPercent = ones(length(mpc1.bus(:,1)),1);
            % for all buses
            for i=1:length(mpc1.bus(:,1))
                LSCooPercent(i) = LSCooPercent(i)*(1-NoCoopPercentage);
            end
            % for only geneartors: a filter to make sure gens' values in the vector are 0
            for i=1:length(mpc1.bus(:,1))
                if(mpc1.bus(i,2)==2 || mpc1.bus(i,2)==3)
                    LSCooPercent(i)=0;
                end
            end
            % end of theta section
            %     opt=mpoption('VERBOSE',0,'OUT_SYS_SUM',0,'OUT_ALL',0,'OUT_BUS',0,'OUT_BRANCH',0,'OUT_ALL_LIM',0);
            %     [result2, success]=rundcopf(mpc1,opt);
            %    mpc1.gen
            %% seperates the controllable and uncontrollable part of load buses
            % this make dispatchable loads with percentage of theta
            % note that this mpc has different number of genertors than original
            % mpc
            mpc1 = S_MakePartialLSContGrid(mpc1,LSCooPercent);
            %     mpc1.gen(:,2)
            %     opt=mpoption('VERBOSE',0,'OUT_SYS_SUM',0,'OUT_ALL',0,'OUT_BUS',0,'OUT_BRANCH',0,'OUT_ALL_LIM',0);
            %     [result2, success]=rundcopf(mpc1,opt);
            %     sum(result2.gen(:,2)')
            % end of load dispatchability
            
            % check with unlimited capacity, set capcity value to zero
            %{
    for i=1:163
        mpc1.bus(i,6)=0
    end
            %}
            
            TotalPowerLine = zeros(1,NumBranches);
            TotalGenDem = zeros(1,NumBuses);
            
            %%%%%%%%%%%%%%%%% Initial failure, Add failures %%%%%%%%%%%%%%%
            %
            numIniFail = 3;%+ ceil(1*rand);
            randomindex = randperm(186);
            IniFidx = randomindex(1:numIniFail);
            %}
            %{
            IniFidx = [136 119];
            numIniFail = 2;
            %}
            
            % Start with failure of k-th link
            NewCapM=0; % Maximum Capacity of the failed lines
            CapSum = 0; % Total capacity of the failed lines
            for i=1:length(IniFidx)
                l = IniFidx(i); % index of the failed line
                ListOfFailures(l) = 1; % where ever there is 1 means failure
                % remove the line from adjacency matrix
                [AdjMatrix,mpc1] = S_cutLine(AdjMatrix,mpc1,l);
                
                if Capacity(l) < 5000 % 9900 MW lines are not taken into account
                    CapSum = CapSum + Capacity(l);
                end
                % track the maximum capacity
                if NewCapM<Capacity(l)
                    NewCapM=Capacity(l);
                end
            end
            %% Whenever a failure or load shed happens we save the state of the grid
            StateCounter=StateCounter+1;
            States(StateCounter,1)=sum(ListOfFailures); % total line failure
            States(StateCounter,2)=NewCapM; % Maximum Capacity of the failed lines
            States(StateCounter,3)=-1; % Amount of load shed happend because of the failure in previous step (To Be assigned)
            States(StateCounter,4)=-1; % Amount of load shed in comparing to previous step
            States(StateCounter,5)=Demand; % Initial load(Demand) over the system
            States(StateCounter,8)=0; % needs to be fillout based on the next failures that may happen to see if this state is steady state or not
            States(StateCounter,9)=Capacity(l); % capacity of failed ones
            States(StateCounter,10)=NewCapM; % Maximum  capacity of failed ones
            States(StateCounter,11)=l; % Index of the failed one
            States(StateCounter,12)=Capacity(l); % Capacity of the failed one
            States(StateCounter,13)=0; % Time of the failure event
            States(StateCounter,14)=CapSum; % Accumulation of failed capacities
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            time = 1; % time initialization
            %{
    Fi = sum(ListOfFailures);
    Cmax = States(StateCounter,10);
    Ci = double(Cmax==TrueCaps(1,1))*1 + double(Cmax==TrueCaps(1,2))*2 + double(Cmax==TrueCaps(1,3))*3 + ...
        + double(Cmax==TrueCaps(1,4))*1 + double(Cmax==TrueCaps(1,5))*5;
    currState = 2*length(TrueCaps)*(Fi-1)-1; % index of the state
            %}
            moreFailures=1; % Is any failure happened in previous step?
            while(moreFailures)
                moreFailures=0; % to see we will have more failures or not
                %%%%%%%%%%%%%%% Find the connected components%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                SG = sparse(AdjMatrix);
                [SS, Components]  = graphconncomp(SG,'DIRECTED',false);
                SS;
                numC = zeros(1,SS);
                
                %% drastic change by PD
                %% change of dynamic \theta
                %
                %if StateCounter == 1 % for the second loop
                a_rho = 1; % fix action always
                %a_rho = opt_pol(currState,time);
                %{
        if mod(currState,2) == 0
            a_rho = 4;
        elseif currState <= 50
            a_rho = 4;
        elseif currState <= 200
            a_rho = 1;
        elseif currState <= 500
            a_rho = 2;
        elseif currState <= 1800
            a_rho = 1;
        end
                %}
                
                %{
        NoCoopPercentage = theta_vector(1,a_rho);
        %NoCoopPercentage = 0.45;
        if StateCounter == 1
            genIdx = NumGens;
            for i = 1:length(mpc1.bus(:,1))
                if(LSCooPercent(i)~=0) % if this is not a pure generator
                    genIdx = genIdx + 1;
                    LSCVector = 1-NoCoopPercentage;
                    mpc1.gen(genIdx,2)= -1*LSCVector*busDemand(i); % Pg (Assign the load on the bus as negative gen value)
                    mpc1.gen(genIdx,10)= -1*LSCVector*busDemand(i); % Actual demand Pmin
                    mpc1.bus(i,3)= (1-LSCVector)*busDemand(i); % this was not done in dispacthed load function
                %{
                        mpc1.gen(genIdx,2)= -1*LSCVector*mpc1.bus(i); % Pg (Assign the load on the bus as negative gen value)
                        mpc1.gen(genIdx,10)= -1*LSCVector*mpc1.bus(i); % Actual demand Pmin
                        mpc1.bus(i,3)= (1-LSCVector)*mpc1.bus(i); % this was not done in dispacthed load function
                %}
                end
            end
        else
            genIdx = NumGens;
            for i = 1:length(mpc1.bus(:,1))
                if(LSCooPercent(i)~=0) % if this is not a pure generator
                    genIdx = genIdx + 1;
                    LSCVector = 1-NoCoopPercentage;
                    mpc1.gen(genIdx,2)= 1*LSCVector*TotalGenDem(i); % Pg (Assign the load on the bus as negative gen value)
                    mpc1.gen(genIdx,10)= 1*LSCVector*TotalGenDem(i); % Actual demand Pmin
                    mpc1.bus(i,3)= (1-LSCVector)*busDemand(i); % this was not done in dispacthed load function
                %{
                        mpc1.gen(genIdx,2)= -1*LSCVector*mpc1.bus(i); % Pg (Assign the load on the bus as negative gen value)
                        mpc1.gen(genIdx,10)= -1*LSCVector*mpc1.bus(i); % Actual demand Pmin
                        mpc1.bus(i,3)= (1-LSCVector)*mpc1.bus(i); % this was not done in dispacthed load function
                %}
                end
            end
        end
                %}
                % end of theta section
                % ************* end of change by PD *************
                %{
                reduce_load = 0.992;
                load_shed_percentage = 1-reduce_load;
                if StateCounter == 4 % for the second loop
                 for i=NumGens+1:length(mpc1.gen(:,1))
                     mpc1.gen(i,2) = (1-load_shed_percentage)*mpc1.gen(i,2); % Pg (Assign the load on the bus as negative gen value)                  
                     mpc1.gen(i,10) = (1-load_shed_percentage)*mpc1.gen(i,10); % Actual demand Pmin
                     % we can implement \theta as follows
                     %{
                     mpc1.gen(i,2) = (1-load_shed_percentage)*(1-theta)*mpc1.gen(i,2)+theta*mpc1.gen(i,2); % Pg (Assign the load on the bus as negative gen value)                  
                     mpc1.gen(i,10) = (1-load_shed_percentage)*mpc1.gen(i,10); % Actual demand Pmin; % Pg (Assign the load on the bus as negative gen value)
                     %}                    
                 end
                end
                %}
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% Run the OPF for every island of the power grid due to failure%%%%%%%%%
                [G,P,VB] = S_islandedGrid(mpc1,Components,SS);
                TotalPowerLine=P;
                TotalGenDem=G;
                %sum(TotalGenDem(:,1));
                %sum(TotalGenDem(:,2));
                %sum(TotalGenDem>0)
                %% Check the load shed amount %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Served=0;
                generation = 0;
                dispatched_served = 0;
                for i=1:NumBuses
                    if(DemandIndex(i)==1)
                        Served=Served+abs(TotalGenDem(i,1))+abs(TotalGenDem(i,2)); % change by PD
                        dispatched_served = dispatched_served + abs(TotalGenDem(i,1));
                    else
                        generation = generation + abs(TotalGenDem(i,1));
                    end
                end
                %{
        Served;
        plot(time,Served,'*')
        hold on
        plot(time,sum(TotalGenDem(:,2)),'o')
                %}
                
                TotalShed=round(Demand-Served);
                States(StateCounter,3)=TotalShed;
                if(States(StateCounter,13)==0) % if this is the first failure
                    States(StateCounter,4)=TotalShed;
                else
                    States(StateCounter,4)=States(StateCounter,3)-States(StateCounter-1,3);
                end
                
                %%%% Set the new generation values as the initial gen and demand of buses%
                % (??????????? what is this, why ???????????????????)
                %{
        for i=1:NumGens % i think it should be Number of buses, because:
            mpc1.gen(i,2)=TotalGenDem(i); % (1) TotalGenDem is initiailzed with number of buses and
        end                               % (2) TotalGenDem is the generation and demand value at each bus
                %}
                
                
                
                %% Check for more failure %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                currentTime=States(StateCounter,13);
                [FailedIndex, moreFailures, LinkProb]=...
                    S_FindFailedLink(TotalPowerLine,Capacity,mpc1,ListOfFailures,alpha);
                link_failprobability = LinkProb;
                if(moreFailures==1)
                    StateCounter=StateCounter+1;
                    ListOfFailures(FailedIndex)=1;
                    [AdjMatrix, mpc1]=S_cutLine(AdjMatrix,mpc1,FailedIndex);
                end
                
                if moreFailures==1 % If we have failure we need to save a new state
                    A=find(ListOfFailures>0);
                    States(StateCounter,1)=sum(ListOfFailures); % This state has only one total failure in the topology
                    %  States(StateCounter,2)=Cap; % Total Capacity of failed ones
                    States(StateCounter,3)=-1; % Amount of load shed happend because of the failure in previous step (To Be assigned)
                    States(StateCounter,4)=-1; % Amount of load shed in comparing to previous step
                    States(StateCounter,5)=Demand; % Initial load(Demand) over the system
                    States(StateCounter,8)=0; % needs to be fillout based on the next failures that may happen to see if this state is steady state or not
                    States(StateCounter,11)=FailedIndex; % Index of the failed one
                    States(StateCounter,12)=Capacity(FailedIndex); % Capacity of the failed one
                    %   States(StateCounter,13)=Ftime; % Time of the failure event
                    States(StateCounter,14)=States(StateCounter-1,14)+States(StateCounter,12); % Accumulation of failed capacities
                    %  min and max
                    MinCap=max(TrueCaps);
                    MaxCap=0;
                    for g=1:NumBranches
                        if (ListOfFailures(g)==1)
                            if(Capacity(g)<=MinCap)
                                MinCap=Capacity(g);
                            end
                            if(Capacity(g)>=MaxCap)
                                MaxCap=Capacity(g);
                            end
                        end
                    end
                    States(StateCounter,9)=MinCap; % min capacity of failed ones
                    States(StateCounter,10)=MaxCap; % max capacity of failed ones
                    States(StateCounter-1,8)=StateCounter;
                    NotAbsortState = 1;
                else
                    States(StateCounter,8)=-1; % It means previous state was a steady state
                    NotAbsortState = 0;
                end % end of saving the states
                time = time + 1;
                
                % find current state
                %{
        Fi = sum(ListOfFailures); % current number of failure
        Cmax = States(StateCounter,10); % current cmax
        Ci = double(Cmax==TrueCaps(1,1))*1 + double(Cmax==TrueCaps(1,2))*2 + double(Cmax==TrueCaps(1,3))*3 + ...
            + double(Cmax==TrueCaps(1,4))*1 + double(Cmax==TrueCaps(1,5))*5;
        currState = 2*length(TrueCaps)*(Fi-1) - NotAbsortState; % index of the state
                %}
            end
            a_rho;
            cascade_stop_time = cascade_stop_time + time;
            served_load = served_load + Served;
            load_shed = load_shed + TotalShed;
            failed_line = failed_line + sum(ListOfFailures);
            generated = generated + generation;
            clear mpc1
        end
        cascade_stop_time_all(theta_idx,r_idx) = cascade_stop_time/NumIt
        failed_line_all(theta_idx,r_idx) = failed_line/(NumIt*186)
        load_shed_all(theta_idx,r_idx) = load_shed/(NumIt*Demand)
        served_load_all(theta_idx,r_idx) = served_load/(NumIt*Demand);
        generated_all(theta_idx,r_idx) = generated/(NumIt*Generation);
        total_cost(theta_idx,r_idx) = failed_line_all(theta_idx,r_idx) + load_shed_all(theta_idx,r_idx)
        
        %percentage_served_all(theta_idx,r_idx) = served_load_all(theta_idx,r_idx)/Demand;
        r_idx = r_idx + 1;
        toc
        % plot(theta,failed_line/NumBranches,'*-',theta,load_shed/(DGRatio*Demand),'o--')
        % hold on    
    end
    %{
    plot(DGRatioVector,failed_line_all(theta_idx,:),'*-',DGRatioVector,load_shed_all(theta_idx,:),'o--')%,...
        %DGRatioVector,served_load_all(theta_idx,:),':d','linewidth',3)
    hold on
    %}
    theta_idx = theta_idx + 1;
end
%plot(theta_vector,failed_line_all','*-',theta_vector,load_shed_all','o--',theta_vector,total_cost','^:')%,...
        %DGRatioVector,served_load_all(theta_idx,:),':d','linewidth',3)


%
%plot(DGRatioVector,failed_line_all(1,:),'*-',DGRatioVector,load_shed_all(1,:),'o--';%,...
        %DGRatioVector,served_load_all(1,:),':d','linewidth',3)
theta_vector = [0.1 0.4 0.6 0.9];        
plot(theta_vector,failed_line_all','*-',theta_vector,load_shed_all','o--','linewidth',3)    
xlabel('\theta')
ylabel('Percentage')
legend('Failed line in steady state','Load shed in steady state')
%legend('failed line, \theta = 0.05','Load shed, \theta = 0.05','Served load, \theta = 0.05',...
%'failed line, \theta = 0.7','Load shed, \theta = 0.7','Served load, \theta = 0.7')
set(gca,'Fontname','Helvetica')
set(gca,'Fontsize',18)
%}

figure(2)
plot(load_shed_all',failed_line_all','-','linewidth',3)
xlabel('Load shed in steady state')
ylabel('Failed line in steady statee')
set(gca,'Fontname','Helvetica')
set(gca,'Fontsize',18)

%{
Blackoutsize=zeros(NumBranches,1);
for i=1:length(States(:,1))
    if(States(i,8)==-1)
        Blackoutsize(States(i,1))=Blackoutsize(States(i,1))+1;
    end
end
%}
