#!/usr/bin/env bash
set -ex

SESSION="srs5ge2e"

cat <<EOF > ~/.tmux.conf
set -g mouse on
set -g pane-border-status top
set -g pane-border-format "#{pane_title}"
set-window-option -g window-status-current-style bg=#f5f5dc
set -g default-terminal "screen-256color"

set-option -g status-justify left
set-option -g status-left '#[bg=colour72] #[bg=colour237] #[bg=colour236] #[bg=colour235]#[fg=colour185] #[bg=colour236] '
set-option -g status-left-length 16
set-option -g status-bg colour237
set-option -g status-right '#[bg=colour236] #[bg=colour235]#[fg=colour185] %a %R #[bg=colour236]#[fg=colour3] #[bg=colour237] #[bg=colour72] #[]'
set-option -g status-interval 60

set-window-option -g window-status-format '#[bg=colour238]#[fg=colour110] #I #[bg=colour239]#[fg=colour110] #[bg=colour240]#W#[bg=colour239]#[fg=colour195]#F#[bg=colour238] '
set-window-option -g window-status-current-format '#[bg=colour236]#[fg=colour231] #I #[bg=colour235]#[fg=colour231] #[bg=colour234]#W#[bg=colour235]#[fg=colour195]#F#[bg=colour236] '
EOF

if sudo docker ps | grep -q open5gs; then
    sudo docker compose -f /opt/srsRAN_Project/docker/docker-compose.yml down 5gc
fi
tmux kill-server || true
tmux new-session -d -s $SESSION
tmux rename-window -t $SESSION:0 'open5gs and tshark'
tmux split-window -v -t $SESSION:0.0
tmux select-pane -t $SESSION:0.0 -T 'open5gs container logs'
tmux send-keys -t $SESSION:0.0 'sudo docker compose -f /opt/srsRAN_Project/docker/docker-compose.yml up 5gc' Enter
while ! ping 10.53.1.2 -c 1 -W 1 > /dev/null 2>&1; do sleep 1; done
tmux send-keys -t $SESSION:0.1 'ran_network_id=$(sudo docker network inspect -f {{.Id}} docker_ran)' Enter
tmux send-keys -t $SESSION:0.1 'ran_bridge_name="br-${ran_network_id:0:12}"' Enter
tmux send-keys -t $SESSION:0.1 'sudo tshark -i $ran_bridge_name' Enter
tmux select-pane -t $SESSION:0.1 -T 'tshark trace'
tmux new-window -t $SESSION:1 -n 'srsran gnb and ue'
sleep 10
tmux send-keys -t $SESSION:1.0 'sudo gnb -c /etc/srsran/gnb.conf' Enter
tmux select-pane -t $SESSION:1.0 -T 'srs gnb logs'
sleep 5
tmux split-window -v -t $SESSION:1.0
if ! ip netns | grep -q ue1; then
    tmux send-keys -t $SESSION:1.1 'sudo ip netns add ue1' Enter
fi
tmux send-keys -t $SESSION:1.1 'sudo srsue' Enter
tmux select-pane -t $SESSION:1.1 -T 'srs ue logs'
tmux split-window -h -t $SESSION:1.1
while ! sudo ip netns exec ue1 ping -c1 -W 1 10.45.1.1 > /dev/null 2>&1; do sleep 1; done
tmux send-keys -t $SESSION:1.2 'sudo ip netns exec ue1 ping 10.45.1.1' Enter
tmux select-pane -t $SESSION:1.2 -T 'ue1 ping open5gs upf'
tmux attach-session -t $SESSION
