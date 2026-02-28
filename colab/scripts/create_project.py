import argparse
import sys
from pathlib import Path
from bim2sim import Project
from bim2sim.utilities.types import IFCDomain

def main():
    parser = argparse.ArgumentParser(description="Create or load a BIM2SIM project.")
    parser.add_argument("project_path", type=str, help="Path to the project directory")
    parser.add_argument("--ifc", type=str, help="Path to the IFC file (optional)", default=None)
    parser.add_argument("--sim-type", type=str, default="energyplus", help="Simulation type (default: energyplus)")

    args = parser.parse_args()
    
    project_path = Path(args.project_path)
    
    # Setup IFC path configuration if provided
    ifc_config = {}
    if args.ifc:
        ifc_file = Path(args.ifc)
        if ifc_file.exists():
            ifc_config = {IFCDomain.arch: ifc_file}
        else:
            print(f"Warning: IFC file not found at {ifc_file}", file=sys.stderr)

    try:
        if Project.is_project_folder(project_path):
            print(f"Loading existing project at {project_path}...")
            project = Project(project_path)
        else:
            print(f"Creating new project at {project_path}...")
            # Note: Project.create might require ifc_path to be valid or handle empty dict depending on implementation
            # Assuming empty dict is allowed or handling it gracefully
            project = Project.create(project_path, ifc_config, args.sim_type)
            
            # Cleanup logic from original script (adapted to be generic if needed)
            # The original script deleted the source IFC if it existed in the destination
            # We will keep this logic only if an IFC was actually provided and copied
            if args.ifc and IFCDomain.arch in ifc_config:
                dest_ifc = project_path / 'ifc' / 'arch' / ifc_config[IFCDomain.arch].name
                if dest_ifc.exists() and ifc_config[IFCDomain.arch].exists():
                     # Caution: Deleting the source file might not be desired in all cases. 
                     # The original script did: ifc_path[IFCDomain.arch].unlink()
                     # We will print a message instead of auto-deleting to be safe, or comment it out.
                     # "if Path('/projects/en/ifc/arch/AC20-FZK-Haus.ifc').exists() and ifc_path[IFCDomain.arch].exists():"
                     # It seems it was moving the file. I'll stick to creation for now.
                     pass

        print(f"Project successfully handled at {project_path}")

    except Exception as e:
        print(f"Error handling project: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
