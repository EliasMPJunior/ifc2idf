import sys
import os
from pathlib import Path
import argparse
import urllib.request
import shutil
import logging

def main():
    # Configuração de Logging para ver tudo o que o bim2sim está fazendo
    logging.basicConfig(level=logging.INFO, stream=sys.stdout, format='%(levelname)s: %(message)s')
    
    parser = argparse.ArgumentParser(description="Run a BIM2SIM project simulation.")
    parser.add_argument("project_path", type=str, help="Path to the project directory")
    args = parser.parse_args()
    
    project_path = Path(args.project_path).absolute()
    
    # Tenta importar bim2sim
    try:
        from bim2sim import Project
        from bim2sim.utilities.types import IFCDomain
    except ImportError as e:
        print(f"Erro crítico: bim2sim não encontrado. {e}")
        sys.exit(1)

    try:
        print(f"=== Iniciando execução para: {project_path.name} ===")
        print(f"Caminho absoluto do projeto: {project_path}")
        
        # 1. Identificação e Configuração do IFC
        # O usuário armazena IFCs em projects/{project_name}/ifc/
        ifc_dir = project_path / 'ifc'
        found_ifc = None
        
        if ifc_dir.exists():
            # CORREÇÃO: O bim2sim exige que o IFC esteja em uma subpasta com o nome do domínio (ex: arch)
            # Se o usuário colocou direto em 'ifc/', movemos para 'ifc/arch/'
            root_ifcs = list(ifc_dir.glob('*.ifc'))
            if root_ifcs:
                print(f"-> Detectado(s) arquivo(s) IFC na raiz de 'ifc/'. Movendo para 'ifc/arch/' para compatibilidade...")
                arch_dir = ifc_dir / 'arch'
                arch_dir.mkdir(exist_ok=True)
                for f in root_ifcs:
                    dest = arch_dir / f.name
                    print(f"   Movendo {f.name} -> {dest}")
                    shutil.move(str(f), str(dest))
            
            # Busca prioritária na raiz de /ifc/ (agora vazia) ou subpastas
            candidates = list(ifc_dir.rglob('*.ifc'))
            
            if candidates:
                found_ifc = candidates[0]
                print(f"-> IFC detectado: {found_ifc.name} (Domínio: {found_ifc.parent.name})")
                if len(candidates) > 1:
                    print(f"   (Aviso: Múltiplos IFCs encontrados. Usando o primeiro: {found_ifc.name})")

        # 2. Carregamento ou Criação do Projeto
        project = None
        
        if Project.is_project_folder(project_path):
            print("-> Carregando projeto existente...")
            project = Project(project_path)
        elif found_ifc:
            print("-> Projeto não inicializado. Criando estrutura a partir do IFC encontrado...")
            ifc_paths = {
                IFCDomain.arch: found_ifc
            }
            # open_conf=False para evitar tentar abrir editor visual no Colab
            project = Project.create(project_path, ifc_paths, 'energyplus', open_conf=False)
        else:
            print("ERRO: Projeto não encontrado e nenhum arquivo .ifc localizado em 'ifc/' para criação.")
            sys.exit(1)

        # Configurações básicas de simulação
        project.sim_settings.run_full_simulation = True
        project.sim_settings.create_plots = True # Habilita criação de gráficos
        
        print(f"Configurações: Full Sim={project.sim_settings.run_full_simulation}, Plots={project.sim_settings.create_plots}")
        
        # Verifica se há arquivo climático configurado
        if not project.sim_settings.weather_file_path:
            print("Aviso: weather_file_path não configurado. Tentando localizar arquivo .epw padrão...")
            
            # Estratégia de busca: 1. Pasta do projeto, 2. Pasta weather global
            # Assumindo que este script está em src/scripts/, weather global estaria em data/weather (../../data/weather)
            script_dir = Path(__file__).parent.absolute()
            repo_root = script_dir.parent.parent
            
            search_paths = [
                project_path, 
                project_path / 'weather',
                repo_root / 'data' / 'weather',
                repo_root / 'weather'
            ]
            
            found_epw = None
            for p in search_paths:
                if p.exists():
                    epw_files = list(p.glob('*.epw'))
                    if epw_files:
                        found_epw = epw_files[0]
                        break
            
            if found_epw:
                print(f"-> Arquivo climático encontrado e configurado: {found_epw}")
                project.sim_settings.weather_file_path = found_epw
            else:
                print("-> Nenhum arquivo .epw local encontrado. Baixando exemplo - Florianopolis...")
                try:
                    # URL do GitHub Raw como fallback seguro (arquivo pequeno de exemplo seria ideal)
                    # Usando URL da OneBuilding ou similar que seja direto
                    epw_url = "https://github.com/BIM2SIM/bim2sim-test-resources/blob/a30bdad1c6103d18c2a504dad1835ad2f5d6aeaf/weather_files/DEU_NW_Aachen.105010_TMYx.epw"
                    
                    dest_epw = project_path / "weather" / "DEU_NW_Aachen.105010_TMYx.epw"
                    dest_epw.parent.mkdir(parents=True, exist_ok=True)
                    
                    print(f"Baixando de {epw_url}...")
                    urllib.request.urlretrieve(epw_url, dest_epw)
                    
                    print(f"-> Download concluído: {dest_epw}")
                    project.sim_settings.weather_file_path = dest_epw
                except Exception as e:
                    print(f"Erro ao tentar configurar clima automaticamente: {e}")
                    print("Por favor, coloque um arquivo .epw na pasta do projeto manualmente.")
                    sys.exit(1)
        
        print("Iniciando pipeline de execução...")
        
        # Loop de execução e tomada de decisão
        for bunch in project.run():
            if not bunch:
                continue
                
            print("\n--- Decisões Necessárias ---")
            for decision in bunch:
                print(f"\nQuestão: {decision.question}")
                print(f"Opções: {decision.options}")
                if decision.default is not None:
                    print(f"Padrão: {decision.default}")
                
                # Lógica de decisão automática para modo não-interativo
                if decision.default is not None:
                    print(f"-> Usando valor padrão: {decision.default}")
                    decision.value = decision.default
                elif decision.options:
                    val = list(decision.options)[0]
                    print(f"-> Sem padrão, selecionando primeira opção: {val}")
                    decision.value = val
                else:
                    print("-> Erro: Decisão sem padrão e sem opções claras. Tentando None.")
                    decision.value = None
                    
        print("\n=== Execução finalizada com sucesso! ===")
        
        # Verificação final de exports
        print("\n=== Verificando arquivos gerados em 'export' ===")
        export_dir = project_path / 'export'
        if export_dir.exists():
            count = 0
            for root, dirs, files in os.walk(export_dir):
                level = root.replace(str(export_dir), '').count(os.sep)
                indent = ' ' * 2 * (level)
                print(f"{indent}[DIR] {os.path.basename(root)}/")
                subindent = ' ' * 2 * (level + 1)
                for f in files:
                    print(f"{subindent}{f}")
                    count += 1
            print(f"\nTotal de arquivos encontrados: {count}")
        else:
            print(f"ALERTA: Diretório de exportação não encontrado: {export_dir}")
            print(f"Conteúdo da pasta do projeto {project_path}:")
            for x in project_path.iterdir():
                print(f" - {x.name} ({'DIR' if x.is_dir() else 'FILE'})")

    except Exception as e:
        print(f"Erro durante a execução: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
