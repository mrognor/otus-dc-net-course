import tomllib
from pathlib import Path
from typing import Literal
from jinja2 import Environment, FileSystemLoader

from pydantic import BaseModel, field_serializer


NodeType = Literal["linux", "frr"]


class ContainerlabNodeModel(BaseModel):
    node_name: str
    node_type: NodeType

    @field_serializer("node_type")
    def serialize_node_type(self, node_type: NodeType) -> dict[str, str]:
        match node_type:
            case "linux":
                return {"kind": "linux", "image": "alpine-frr-client:0.1"}

            case "frr":
                return {"kind": "linux", "image": "alpine-frr-switch:0.1"}


if __name__ == "__main__":
    nodes : list[dict[str, str]] = []

    pathlist = Path(".").rglob('*.toml')
    for path in pathlist:
        with open(str(path), "rb") as data_file:
            nodes.append(ContainerlabNodeModel.model_validate(tomllib.load(data_file)).model_dump())

    print(nodes)

    with open("lab.clab.yaml", "w", encoding="utf-8") as clab_file:
        env = Environment(loader=FileSystemLoader("."))
        template_text = env.get_template("lab.clab.yaml.j2").render({"nodes": nodes})
        _ = clab_file.write(template_text)
