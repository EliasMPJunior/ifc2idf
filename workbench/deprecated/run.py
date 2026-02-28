from bim2sim import Project
from pathlib import Path

# após criar/carregar `project`
from bim2sim.utilities.types import IFCDomain

project_path = '/projects/ifc2sb'

ifc_path = {IFCDomain.arch: Path('/projects/ifc2sb/ifc/arch/Projeto_revit_ifc4.ifc')}
# ifc_path = {IFCDomain.arch: Path('/projects/ifc2sb/ifc/arch/AC20-FZK-Haus.ifc')}

project = Project(project_path)
project.sim_settings.run_full_simulation = True
# project.sim_settings.sb_generate_2b = False
project.sim_settings.weather_file_path = Path('/projects/ifc2sb/weather_files/BRA_SC_Florianopolis-Luz.AP.838990_TRY.1963.epw')
# project.sim_settings.weather_file_path = Path('/projects/ifc2sb/weather_files/BRA_SP_Sao.Paulo-Congonhas.AP.837800_TMYx.2009-2023.epw')

# Option 1: handle decisions manually
for bunch in project.run():
    for decision in bunch:
        print(decision.question)
        decision.value = 42  # your logic goes here
