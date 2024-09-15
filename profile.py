import os

import geni.portal as portal
import geni.rspec.pg as rspec
import geni.rspec.igext as IG
import geni.rspec.emulab as emulab

tourDescription = """

### srsRAN 5G with Open5GS and Simulated RF

This profile instantiates a single-node experiment for running and end to end 5G network using srsRAN_Project 24.04 (gNodeB), srsRAN_4G (UE), and Open5GS with IQ samples passed via ZMQ between the gNodeB and the UE. It requires a single Dell d430 compute node.

"""
tourInstructions = """

Startup scripts will still be running when your experiment becomes ready. Watch the "Startup" column on the "List View" tab for your experiment and wait until all of the compute nodes show "Finished" before proceeding.

Note: You will be opening several SSH sessions on a single node. Using a terminal multiplexing solution like `screen` or `tmux`, both of which are installed on the image for this profile, is recommended.

After all startup scripts have finished...

In an SSH session on `node`:

```
# create a network namespace for the UE
sudo ip netns add ue1

# start 5gc container
sudo docker compose -f /opt/srsRAN_Project/docker/docker-compose.yml up 5gc
```

In a second session:

```
# use tshark to monitor 5G core network function traffic
ran_network_id=$(sudo docker network inspect -f {{.Id}} docker_ran)
ran_bridge_name="br-${ran_network_id:0:12}"
sudo tshark -i $ran_bridge_name
```

In a third session:

```
# start the gNodeB
sudo gnb -c /etc/srsran/gnb.conf
```

The 5GC container logs should show a connection from the gNodeB via the N2 interface and `tshark` will show NG setup/response messages.

In a forth session:

```
# start the UE
sudo srsue
```

As the UE attaches to the network, the AMF log and gNodeB process will show progress and you will see NGAP/NAS traffic in the output from `tshark` as a PDU session for the UE is eventually established.

At this point, you should be able to pass traffic across the network via the previously created namespace in yet another session on the same node:

```
# start pinging the Open5GS data network
sudo ip netns exec ue1 ping 10.45.1.1
```

You can also use `iperf3` to generate traffic. E.g., for downlink, in one session:

```
# start iperf3 server within the 5gc docker container
sudo docker exec -it open5gs_5gc iperf3 -s
```

And in another:

```
# start iperf3 client for UE and pass traffic on the downlink
sudo ip netns exec ue1 iperf3 -c 10.45.1.1 -R
```

Note: When ZMQ is used by srsRAN to pass IQ samples, if you restart either of the `gnb` or `srsue` processes, you must restart the other as well.

You can find more information about the open source 5G software used in this profile at:

https://open5gs.org
https://github.com/srsran/srsRAN_Project
"""


BIN_PATH = "/local/repository/bin"
ETC_PATH = "/local/repository/etc"
SRS_DEPLOY_SCRIPT = os.path.join(BIN_PATH, "deploy-srs.sh")
UBUNTU_IMG = "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD"
DEPLOYED_UBUNTU_IMG = "urn:publicid:IDN+emulab.net+image+PowderTeam:srsran5g-simulated-rf"
DEFAULT_SRS_HASHES = {
    "srsRAN_4G": "release_23_11",
    "srsRAN_Project": "release_24_04",
}

pc = portal.Context()
node_types = [
    ("d430", "Emulab, d430"),
    ("d740", "Emulab, d740"),
]

pc.defineParameter(
    name="nodetype",
    description="Type of compute node to used.",
    typ=portal.ParameterType.STRING,
    defaultValue=node_types[0],
    legalValues=node_types,
    advanced=True,
)

pc.defineParameter(
    name="do_deploy",
    description="Run deploy scripts for srsRAN_Project and srsRAN_4G",
    typ=portal.ParameterType.BOOLEAN,
    defaultValue=True,
    advanced=True,
)

pc.defineParameter(
    name="enable_vnc",
    description="Enable browser-based VNC server.",
    typ=portal.ParameterType.BOOLEAN,
    defaultValue=False,
    advanced=True,
)

params = pc.bindParameters()
pc.verifyParameters()
request = pc.makeRequestRSpec()

node = request.RawPC("node")
node.hardware_type = params.nodetype

if params.do_deploy:
    node.disk_image = UBUNTU_IMG
    for srs_type, type_hash in DEFAULT_SRS_HASHES.items():
        cmd = "sudo {} '{}' {}".format(SRS_DEPLOY_SCRIPT, type_hash, srs_type)
        node.addService(rspec.Execute(shell="bash", command=cmd))
else:
    node.disk_image = DEPLOYED_UBUNTU_IMG

if params.enable_vnc:
    node.startVNC()

tour = IG.Tour()
tour.Description(IG.Tour.MARKDOWN, tourDescription)
tour.Instructions(IG.Tour.MARKDOWN, tourInstructions)
request.addTour(tour)

pc.printRequestRSpec(request)
