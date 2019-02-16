import java.util
import java.util.Scanner
import java.io.BufferedReader
import java.io.InputStreamReader

object ejemplo {
  def main(args:Array[String]) {
   
    print("\n>>>>>>           Toy Blast           <<<<<<\n")
    println("--------------------------------------------")
    
    val reader = new Scanner(System.in)
    println("Introduce el nivel seleccionado (1/2/3):")
    val nivel = reader.nextInt();
		seleccionNivel(nivel)
  
}
  
  def seleccionNivel(nivel:Int):Unit = {
    /* El nivel 1 del juego se mostrará tableros de 7x9 en el que se presentará un
			tablero lleno de bloques de hasta 4 colores aleatorios.*/
    if(nivel==1){ // En el caso de que se seleccione el nivel 1
      val fil = 7
      val col = 9
      val ale = 4 // Hasta 4 colores aleatorios
      val m = generarTablero(col*fil)
      val m5 = generarAle(m,ale)
      val mov_max = 10 // Numero de movimientos máximos, queda pendiente de modificar con los objetos
      jugada(mov_max,m5,fil,col,ale)
      
    }else{
      if (nivel == 2){ //Si estoy en el nivel 2
        
        val fil = 11
        val col = 17
        val ale = 5 
        val m = generarTablero(col*fil)
        val m5 = generarAle(m,ale)
        val mov_max = 10 // Numero de movimientos máximos, queda pendiente de modificar con los objetos
        jugada(mov_max,m5,fil,col,ale)
        
      }else{
        if(nivel == 3){ // Si estoy en el nivel 3
          val fil = 15
        val col = 27
        val ale = 6 
        val m = generarTablero(col*fil)
        val m5 = generarAle(m,ale)
        val mov_max = 10 // Numero de movimientos máximos, queda pendiente de modificar con los objetos
         jugada(mov_max,m5,fil,col,ale)
          
        }else{
          println("Ha seleccionado un nivel erroneo, introduzca otro nivel(1/2/3):")
          val reader = new Scanner(System.in)
          val ni = reader.nextInt();
          seleccionNivel(ni)
        }
      }
      
    }
    
  }
  
  def jugada(movimientos:Int, tablero:List[Int],fil:Int,col:Int, max:Int):Unit = {
      if(movimientos == 0 ) {
        println("Partida finalizada: ")
        imprimirTablero(tablero,col,fil)
      }
      else {
	      println("Tablero actual")
        imprimirTablero2(tablero,col,fil)
        val reader = new Scanner(System.in)
        println("Introduce el numero de fila a eliminar")
        val fil_eli = reader.nextInt();
        println("Introduce el numero de columna a eliminar")
        val col_eli = reader.nextInt();
        //val m6 = eliminarPos(m5, col_eli,fil_eli, col, fil)
        val pos = col_eli + (fil_eli-1) * col
        val m6 = Poner(tablero,0,pos)
        val m3 = movimientos - 1
        jugada(m3,m6,fil,col,max)
      
      }
  
}
  
 
    
    def obtenerColor(l:List[Int], pos:Int): Int={
   		if(pos==0){
   		 val color = l(pos)
   		color
   		}
    	else{
    	 obtenerColor(l.tail,pos-1)
    	}
   }
  
  def generarAle(l:List[Int], max:Int): List[Int] = {
   			if (l.isEmpty) l
   			else{
   				if(l.head==0) {
   					val aleatorio = (Math.random()*(max)) + 1
  					val a = aleatorio.toInt
  					List(a):::generarAle(l.tail,max)
   				}else{
   					List(l.head):::generarAle(l.tail,max)
   				}
   			
   			}
   }
  
  
  def imprimirCabecera(col:Int,num:Int):Unit = {
      if(col==num) println(num)
      else{
        print(num + "\t")
        val n = num + 1
        imprimirCabecera(col,n)
        }
    
    
  }
  
  def imprimirTablero(l:List[Int],col:Int,fil:Int) ={
    print("\t\t")
    imprimirCabecera(col,1)
    println("-----------" * col)
    print("1\t| \t")
  		imprimir_aux(l,col-1,0,1,fil)
  }
  
def imprimir_aux(l:List[Int],salto:Int,n:Int,fil:Int,fil_final:Int):Unit = {
  	if(l.isEmpty) print("\n")
  	else if(n==salto){
  	
  				print(l.head)
  				val f = fil+1
  				if(f>fil_final){
  				  print("\t\n")
  				  
  				}else{
  				  print("\t\n"+ f +"\t|\t" )
  				}
  				
  				imprimir_aux(l.tail, salto, 0,f,fil_final)
  				
  				
  		} else {
  			print(l.head)
  			print("\t")
  			imprimir_aux(l.tail, salto, n+1,fil,fil_final)
  		}
  }

def imprimirTablero2(l:List[Int],col:Int,fil:Int) ={
    print("\t\t")
    imprimirCabecera(col,1)
    println("-----------" * col)
    print("1\t| \t")
  		imprimir_aux2(l,col-1,0,1,fil)
  }
  

def imprimir_cabeza(num:Int) = num match {
  
  case 0 => print("-")
  case 1 => print("A")
  case 2 => print("R")
  case 3 => print("N")
  case 4 => print("V")
  case 5 => print("P")
  case 6 => print("M")
  case 7 => print("G")
  case 8 => print("B")
  
}

def imprimir_aux2(l:List[Int],salto:Int,n:Int,fil:Int,fil_final:Int):Unit = {
  	if(l.isEmpty) print("\n")
  	else if(n==salto){
  	
  				imprimir_cabeza(l.head)
  				val f = fil+1
  				if(f>fil_final){
  				  print("\t\n")
  				  
  				}else{
  				  print("\t\n"+ f +"\t|\t" )
  				}
  				
  				imprimir_aux2(l.tail, salto, 0,f,fil_final)
  				
  				
  		} else {
  			imprimir_cabeza(l.head)
  			print("\t")
  			imprimir_aux2(l.tail, salto, n+1,fil,fil_final)
  		}
  }

def Poner (l: List [Int], color: Int, posición: Int): List [Int] = posición match {
  	case 1 => List (color) ::: l.tail // si la posición coincide metemos el color con el resto de la lista
  	case _ => l.head :: Poner (l.tail, color, (posición-1)) // si no llamamos con una posición menos
  	
  } 
  
 def generarTablero(col:Int): List[Int] = col match{
		  case 0 => Nil
		  case _ => (0)::generarTablero(col-1)
	  }
 }






