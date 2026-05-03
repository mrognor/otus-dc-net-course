import os
import stat
import tomllib
from pathlib import Path
from typing import Literal, cast, override
from jinja2 import Environment, FileSystemLoader

from pydantic import BaseModel, field_serializer

configs_path = "labs/lab1"
lab_path = "labs/lab1"

NodeType = Literal["linux", "frr"]
FrrDaemon = Literal["bfdd", "ospfd", "ospf6d"]


class Link:
    link_endpoints: tuple[str, str]

    def __init__(self, node1_link: str, node2_link: str):
        self.link_endpoints = cast(tuple[str, str], tuple(sorted((node1_link, node2_link))))

    @override
    def __eq__(self, rhs: object) -> bool:
        return isinstance(rhs, Link) and self.link_endpoints == rhs.link_endpoints

    @override
    def __hash__(self) -> int:
        # No problem with collision if iface names compares
        return hash(self.link_endpoints)

    @override
    def __repr__(self) -> str:
        return str(self.link_endpoints)


class ContainerlabNeighIfaceModel(BaseModel):
    neigh: str
    iface: str


class LinuxConfig(BaseModel):
    net: str


class OspfdFrrConfig(BaseModel):
    instances: list[int] | None = None


class FrrConfig(BaseModel):
    net: str
    daemons: list[FrrDaemon]
    ospfd: OspfdFrrConfig | None = None


class ContainerlabNodeModel(BaseModel):
    enable: bool = True
    node_name: str
    node_type: NodeType
    links: dict[str, ContainerlabNeighIfaceModel]
    linux: LinuxConfig | None = None
    frr: FrrConfig | None = None

    @field_serializer("node_type")
    def serialize_node_type(self, node_type: NodeType) -> dict[str, str]:
        match node_type:
            case "linux":
                return {"type": "linux", "kind": "linux", "image": "alpine-client:0.1"}

            case "frr":
                return {"type": "frr", "kind": "linux", "image": "alpine-frr-switch:0.1"}


if __name__ == "__main__":
    j2_env = Environment(loader=FileSystemLoader("templates"))

    # Read user toml files and parse it
    nodes: list[ContainerlabNodeModel] = []
    pathlist = Path(configs_path).rglob('*.toml')
    for path in pathlist:
        with open(str(path), "rb") as data_file:
            toml_node = tomllib.load(data_file)
            clab_node = ContainerlabNodeModel.model_validate(toml_node)
            if clab_node.enable: 
                nodes.append(clab_node)

    # Get links from user toml files
    links: dict[Link, int] = {}
    for node in nodes:
        for iface, neigh_link in node.links.items():
            link = Link(f"{node.node_name}:{iface}", f"{neigh_link.neigh}:{neigh_link.iface}")

            if link not in links:
                links.update({link: 0})
            else:
                links.update({link: links[link] + 1})

    # todo add links validation

    # Prepare lab dir
    os.makedirs(lab_path, exist_ok=True)
    os.makedirs(f"{lab_path}/configs", exist_ok=True)

    # Create containerlab topology file
    with open(f"{lab_path}/lab.clab.yaml", "w", encoding="utf-8") as clab_file:
        template_text = j2_env.get_template("lab.clab.yaml.j2").render(
            {
                "nodes": [node.model_dump() for node in nodes],
                "links": [{"endpoint1": link.link_endpoints[0], "endpoint2": link.link_endpoints[1]} for link in links]
            })
        _ = clab_file.write(template_text)

    # Create container configs    
    linux_template = j2_env.get_template("linux.sh.j2")

    for node in nodes:
        # Linux net configuration
        config_file_name = f"{lab_path}/configs/{node.node_name}.sh"
        with open(config_file_name, "w", encoding="utf-8") as conf_file:
            template_text = linux_template.render({"linux": node.linux})
            _ = conf_file.write(template_text)
            os.chmod(config_file_name, os.stat(config_file_name).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

        # Frr net configuration
        if node.frr != None:
            config_file_name = f"{lab_path}/configs/{node.node_name}.frr"
            with open(config_file_name, "w", encoding="utf-8") as conf_file:                
                    _ = conf_file.write(node.frr.net)

    # Files for save commands history in container
    for node in nodes:
        open(f"{lab_path}/configs/{node.node_name}.ash_history", "a").close()
