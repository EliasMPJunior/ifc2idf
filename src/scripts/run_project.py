import sys
import os
from pathlib import Path
import argparse
import urllib.request

def main():
    parser = argparse.ArgumentParser(description="Run a BIM2SIM project simulation.")
    parser.add_argument("project_path", type=str, help="Path to the project directory")
    args = parser.parse_args()
    
    project_path = Path(args.project_path)
    
    # Tenta importar bim2sim
    try:
        from bim2sim import Project
    except ImportError as e:
        print(f"Erro crítico: bim2sim não encontrado. {e}")
        sys.exit(1)

    try:
        print(f"Carregando projeto de {project_path}...")
        project = Project(project_path)
        
        # Configurações básicas de simulação
        project.sim_settings.run_full_simulation = True
        
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
                    epw_url = "https://raw.githubusercontent.com/labeee/weather_files/master/BRA_SC_Florianopolis-Hercilio.Luz.Intl.AP.838990_TMYx.2007-2021/BRA_SC_Florianopolis-Hercilio.Luz.Intl.AP.838990_TMYx.2007-2021.epw"
                    
                    dest_epw = project_path / "weather" / "Florianopolis.epw"
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

    except Exception as e:
        print(f"Erro durante a execução: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
