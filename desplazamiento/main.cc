#include <iostream>
#include <cstdlib>
#include <iostream>
#include <ctime>
#include <string>
#include <sstream>
#include <vector>
#include <math.h>

#define VACIO 0

template <class T>
void generate_vector (T *vector, const int &size) {
  for (int i = 0; i < size; ++i){
    vector [i] = (std::rand() % 3)? VACIO : pow(2,((std::rand() % 4)+ 1));
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
        tablero[ultima_ficha_posicion] = ultima_ficha*2;
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

void movimientoDerecha(float* tablero, int nf, int nc) {
  int id = 0;
  int posicion = nc-1; //nos movemos a través de las columnas de la misma fila 
  int comparador = nc-2;
  int cursor = nc-1;
  while (posicion >= 0 && comparador > -1) {
    //si no se ha llegado al final y ambos números son iguales y distintos de 0 se suman 
    if (posicion > 0 && tablero[id+posicion] == tablero[id+comparador] && tablero[id +posicion] != 0
      && tablero[id+comparador] != 0) {
      int suma = tablero[id + comparador] + tablero[id +posicion];
      tablero[id+posicion] = 0;
      tablero[id +comparador] = 0;
      tablero[id +cursor] = suma;
      cursor--;
      posicion = comparador - 1;
      comparador -= 2;
      
    }
    //si donde nos encontramos es 0
    else if (tablero [id +posicion] == 0) {
      posicion--;
      comparador--;
    } //si el contiguo es 0
    else if (tablero[id +comparador] == 0) {
      comparador--;
    }
    else { // Ambos son diferentes de cero y diferentes entre si
      int aux = tablero[id+posicion];
      tablero[id +posicion] = 0;
      tablero[id+cursor] = aux;
      cursor--;
      posicion = comparador;
      comparador--;
    }
  }
  if (posicion >= 0) {
    int aux = tablero[id+posicion];
    tablero[id+posicion] = 0;
    tablero [id+cursor] = aux;
  }
}
  
void movimientoAbajo(float* tablero, int nf, int nc) {
  int id = 0;
  int posicion = nf - 1; //nos movemos a través de las filas en la misma columna 
  int comparador = nf - 2;
  int cursor = nf - 1;
  while (posicion >= 0 && comparador > -1) {
    if (posicion > 0 && tablero[posicion+id] == tablero[comparador+id] && tablero[posicion+id] != 0
      && tablero[comparador+id] != 0) {
      int suma = tablero[comparador +id] + tablero[posicion + id];
      tablero[posicion+ id] = 0;
      tablero[comparador + id] = 0;
      tablero[cursor + id] = suma;
      cursor--;
      posicion = comparador - 1;
      comparador -= 2;
  
    }
    else if (tablero[posicion + id] == 0) {
      posicion--;
      comparador--;
    }
    else if (tablero[comparador + id] == 0) {
      comparador--;
    }
    else { // Ambos son diferentes de cero y diferentes entre si
      int aux = tablero[posicion + id ];
      tablero[posicion + id] = 0;
      tablero[cursor + id] = aux;
      cursor--;
      posicion = comparador;
      comparador--;
    }
  }
  if (posicion >= 0) {
    int aux = tablero[posicion + id];
    tablero[posicion + id] = 0;
    tablero[cursor + id ] = aux;

  }
}

int main (int argc, char **argv){
  std::srand(std::time(nullptr));
  const int ksize = (argc < 2) ? 10 : std::atoi(argv[1]);
  const int krep = (argc < 3) ? 1 : std::atoi(argv[2]);
  //float *tablero =  (float*) malloc(sizeof(float) * ksize);
  //float tablero[20] = {8,8,0,0,0,4,2,0,8,16,2,0,0,0,0,0,0,0,4,4};
  //float tablero[20] = {0,0,0,0,0,8,8,0,4,4,0,0,16,8,0,0,0,0,16,0};
  float tablero[20] = {2,4,0,0,2,2,0,8,0,0,0,4,0,16,0,2,4,0,0,0};
  for (int i = 0; i < krep; ++i) {
    //generate_vector<float>(tablero, ksize);
    std::cout << "inicial: " << print_vector<float>(tablero, ksize) << std::endl;
    //order_vector<float>(tablero, ksize);
    movimientoAbajo(tablero, ksize, 0);
    std::cout << "final: "<< print_vector<float>(tablero, ksize) << std::endl;
  }
  return 0;
}