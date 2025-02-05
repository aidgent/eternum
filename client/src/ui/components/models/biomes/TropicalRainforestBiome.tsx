import { useGLTF } from "@react-three/drei";
import { getUIPositionFromColRow, pseudoRandom } from "../../../utils/utils";
import * as THREE from "three";
import { useMemo } from "react";
import { Hexagon } from "../../../../types";
import { GLTF } from "three-stdlib";

type GLTFResult = GLTF & {
  nodes: {
    Tropical_Rainforest_Terrain: THREE.Mesh;
    Tropical_Rainforest_Trees_1: THREE.Mesh;
    Tropical_Rainforest_Trees_2: THREE.Mesh;
    Tropical_Rainforest_Treecover: THREE.Mesh;
  };
  materials: {
    ["Tropical Rainforest Dirt"]: THREE.MeshStandardMaterial;
    ["Tropical Rainforest Leaves"]: THREE.MeshStandardMaterial;
    ["Tropical Seasonal Forest Wood"]: THREE.MeshStandardMaterial;
  };
};

export function TropicalRainforestBiome({ hexes, zOffsets }: { hexes: any[]; zOffsets?: boolean }) {
  const { nodes, materials: _materials } = useGLTF("/models/biomes/tropicalRainforest.glb") as GLTFResult;

  const defaultTransform = new THREE.Matrix4()
    .makeRotationX(Math.PI / 2)
    .multiply(new THREE.Matrix4().makeScale(3, 3, 3));

  const geometries = useMemo(() => {
    return [
      nodes.Tropical_Rainforest_Terrain.geometry.clone(),
      nodes.Tropical_Rainforest_Trees_1.geometry.clone(),
      nodes.Tropical_Rainforest_Trees_2.geometry.clone(),
      nodes.Tropical_Rainforest_Treecover.geometry.clone(),
    ].map((geometry) => {
      geometry.applyMatrix4(defaultTransform);
      return geometry;
    });
  }, [nodes]);

  const materials = useMemo(() => {
    return [
      _materials["Tropical Rainforest Dirt"],
      _materials["Tropical Rainforest Leaves"],
      _materials["Tropical Seasonal Forest Wood"],
      _materials["Tropical Rainforest Leaves"],
    ];
  }, [_materials]);

  const meshes = useMemo(() => {
    const instancedMeshes = [...geometries].map((geometry, idx) => {
      const instancedMesh = new THREE.InstancedMesh(geometry, materials[idx], hexes.length);
      return instancedMesh;
    });

    let idx = 0;
    let matrix = new THREE.Matrix4();
    hexes.forEach((hex: any) => {
      const { x, y, z } = hex;
      // rotate hex randomly on 60 * n degrees
      const seededRandom = pseudoRandom(hex.x, hex.y);
      matrix.makeRotationZ((Math.PI / 3) * Math.floor(seededRandom * 6));
      matrix.setPosition(x, y, zOffsets ? 0.32 + z : 0.32);
      instancedMeshes.forEach((mesh) => {
        mesh.setMatrixAt(idx, matrix);
      });
      idx++;
    });

    instancedMeshes.forEach((mesh) => {
      mesh.computeBoundingSphere();
      mesh.frustumCulled = true;
    });
    return instancedMeshes;
  }, [hexes]);

  return (
    <>
      {meshes.map((mesh, idx) => (
        <primitive object={mesh} key={idx} />
      ))}
    </>
  );
}
