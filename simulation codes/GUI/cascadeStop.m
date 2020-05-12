function [cascade_stop] = cascadeStop(States, NumberOfLines)
total_states = zeros(1, NumberOfLines);
stable_states = zeros(1, NumberOfLines);
%for i = 1:length(States(:,1))
for i = 1:length(States)
    if (States(i,1) > 0)
        total_states(States(i,1)) = total_states(States(i,1)) + 1;
        if States(i,8) == -1
            stable_states(States(i,1)) = stable_states(States(i,1)) + 1;
        end
    end
end

cascade_stop = zeros(1, NumberOfLines);
for i = 1:NumberOfLines
    if total_states(i) ~= 0
        cascade_stop(i) = stable_states(i)/total_states(i);
    end
end
end