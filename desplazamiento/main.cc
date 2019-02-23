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
void order_vector (T *tablero, const int &size){
  bool hay_hueco;
  int ultimo_hueco;
  T ultima_ficha;
  int ultima_ficha_posicion;
  hay_hueco = tablero[0] == VACIO;
  if (hay_hueco){
    ultimo_hueco = 0;
    ultima_ficha = 0;
    ultima_ficha_posicion = 0;
  } else {
    ultima_ficha = tablero[0];
    ultima_ficha_posicion = 0;
    ultimo_hueco = 0;
  }

  for (int i = 1; i < size; ++i){
    if (tablero[i] != VACIO){
      if (tablero[i] == ultima_ficha){
        tablero[ultima_ficha_posicion] = ultima_ficha+1;
        ultima_ficha = 0;
        hay_hueco = true;
        ultimo_hueco = ultima_ficha_posicion + 1;
        if (i != ultima_ficha_posicion){
          tablero[i]=VACIO;
        }
        //std::cout << "union de fichas" << std::endl;
      } else {
        if (hay_hueco){
          tablero[ultimo_hueco] = tablero[i];
          ultima_ficha = tablero[i];
          ultima_ficha_posicion = ultimo_hueco;
          ++ultimo_hueco;
          hay_hueco = (ultimo_hueco <= i);
          if (i != ultima_ficha_posicion){
            tablero[i]=VACIO;
          }
          //std::cout << "se puso en el hueco" << std::endl;
        } else {
          ultima_ficha = tablero[i];
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
  char *tablero =  (char*) malloc(sizeof(char) * ksize);
  //char tablero_inicial[20] = {'C','C','0','0','0','B','A','0','C','D','A','0','0','0','0','0','0','0','B','B'};//-->DBACDAC
  //char tablero_inicial[20] = {'0','0','0','0','0','C','C','0','B','B','0','0','D','C','0','0','0','0','D','0'};//-->DCDCD
  //char tablero_inicial[20] = {'A','B','0','0','A','A','0','C','0','0','0','B','0','C','0','A','B','0','0','0'};//-->ABBCBCAB
  for (int i = 0; i < krep; ++i) {
    generate_vector<char>(tablero, ksize);
    std::cout << "inicial: " << print_vector<char>(tablero, ksize) << std::endl;
    order_vector<char>(tablero, ksize);
    std::cout << "final: "<< print_vector<char>(tablero, ksize) << std::endl;
  }
  return 0;
}