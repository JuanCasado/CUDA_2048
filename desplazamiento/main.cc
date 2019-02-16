#include <iostream>
#include <cstdlib>
#include <iostream>
#include <ctime>
#include <string>
#include <sstream>
#include <vector>

#define VACIO '0'

template <class T>
void generate_vector (T *vector, const int &size) {
  char letters[] = {'A', 'B', 'C', 'D'};
  for (int i = 0; i < size; ++i){
    vector [i] = (std::rand() % 3)? VACIO : letters[std::rand() % 4];
  }
}

template <class T>
std::string print_vector (T *vector, const int &size){
  std::stringstream ss;
  ss << "{";
  for (int i = 0; i < size; ++i){
    ss << vector[i] << ",";
  }
  ss << "}";
  return ss.str();
}

template <class T>
void order_vector (T *tablero_salida, T *tablero_entrada, const int &size){
  bool hay_hueco;
  int ultimo_hueco;
  T ultima_ficha;
  int ultima_ficha_posicion;
  
  hay_hueco = tablero_entrada[0] == VACIO;
  if (hay_hueco){
    ultimo_hueco = 0;
    ultima_ficha = 0;
    ultima_ficha_posicion = 0;
  } else {
    ultima_ficha = tablero_entrada[0];
    ultima_ficha_posicion = 0;
    tablero_salida[0] = tablero_entrada[0];
    ultimo_hueco = 0;
  }

  for (int i = 1; i < size; ++i){
    if (tablero_entrada[i] != VACIO){
      if (tablero_entrada[i] == ultima_ficha){
        tablero_salida[ultima_ficha_posicion] = ultima_ficha+1;
        ultima_ficha = 0;
        hay_hueco = true;
        ultimo_hueco = ultima_ficha_posicion + 1;
        //std::cout << "union de fichas" << std::endl;
      } else {
        if (hay_hueco){
          tablero_salida[ultimo_hueco] = tablero_entrada[i];
          ultima_ficha = tablero_entrada[i];
          ultima_ficha_posicion = ultimo_hueco;
          ++ultimo_hueco;
          hay_hueco = (ultimo_hueco <= i);
          //std::cout << "se puso en el hueco" << std::endl;
        } else {
          tablero_salida[i] = tablero_entrada[i];
          ultima_ficha = tablero_entrada[i];
          ultima_ficha_posicion = i;
          ultimo_hueco  = i;
          hay_hueco = false;
          //std::cout << "se puso en paralelo" << std::endl;
        }
      }
    } else {
      if (!hay_hueco){
        hay_hueco = true;
        ultimo_hueco = i;
        //std::cout << "nuevo hueco encontrado" << std::endl;
      }
    }
    //std::cout << "step: "<< print_vector<T>(tablero_salida, size) << std::endl;
  }
}

int main (int argc, char **argv){
  std::srand(std::time(nullptr));
  const int ksize = (argc < 2) ? 10 : std::atoi(argv[1]);
  const int krep = (argc < 3) ? 1 : std::atoi(argv[2]);
  char *tablero_inicial =  (char*) malloc(sizeof(char) * ksize);
  char *tablero_final =  (char*) malloc(sizeof(char) * ksize);
  //char tablero_inicial[20] = {'C','C','0','0','0','B','A','0','C','D','A','0','0','0','0','0','0','0','B','B'};//-->DBACDAC
  //char tablero_inicial[20] = {'0','0','0','0','0','C','C','0','B','B','0','0','D','C','0','0','0','0','D','0'};//-->DCDCD
  //char tablero_inicial[20] = {'A','B','0','0','A','A','0','C','0','0','0','B','0','C','0','A','B','0','0','0'};//-->ABBCBCAB
  memset(tablero_final, 0, sizeof(char) * ksize);
  for (int i = 0; i < krep; ++i) {
    generate_vector<char>(tablero_inicial, ksize);
    std::cout << "inicial: " << print_vector<char>(tablero_inicial, ksize) << std::endl;
    order_vector<char>(tablero_final, tablero_inicial, ksize);
    std::cout << "final: "<< print_vector<char>(tablero_final, ksize) << std::endl;
  }
  return 0;
}