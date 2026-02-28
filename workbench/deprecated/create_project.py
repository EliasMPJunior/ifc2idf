from pathlib import Path
from bim2sim import Project
from bim2sim.utilities.types import IFCDomain

project_path = '/projects/ifc2sb'
# ifc_path = '/projects/ifc2sb/ifc'
ifc_path = {IFCDomain.arch: Path('/projects/ifc2sb/ifc/Projeto_revit_ifc4.ifc')}

if Project.is_project_folder(project_path):
    # load project if existing
    project = Project(project_path)
else:
    # else create a new one
    project = Project.create(project_path, ifc_path, 'energyplus')
    if Path('/projects/ifc2sb/ifc/arch/Projeto_revit_ifc4.ifc').exists() and ifc_path[IFCDomain.arch].exists():
        ifc_path[IFCDomain.arch].unlink()
