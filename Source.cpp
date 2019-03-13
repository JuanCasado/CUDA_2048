#include <GL\glut.h>
#include <GL/GLU.h>



void inicializa() {

	glClearColor(0.0, 0.5, 0.7, 0.0); //Color de fondo

	glMatrixMode(GL_PROJECTION); //Modo de proyeccion
	glLoadIdentity();  //Estable los paramatros de proyeccion 
	gluOrtho2D(-50.0, 50.0, -50.0, 50.0);//vista ortogonal 

}

void dibuja() {
	
	glClear(GL_COLOR_BUFFER_BIT);
	glPolygonMode(GL_FRONT, GL_LINE);
	glColor3f(1.0, 1.0, 1.0);
	int xsize = 0, ysize = 0;
	for (int j = 0; j<5; j++)
	{
		xsize = 0;
		for (int i = 0; i<5; i++)
		{
			glBegin(GL_POLYGON);
			glVertex3f(-50.0 + xsize, -50.0 + ysize, 0.0);
			glVertex3f(-40.0 + xsize, -50.0 + ysize, 0.0);
			glVertex3f(-40.0 + xsize, -40.0 + ysize, 0.0);
			glVertex3f(-50.0 + xsize, -40.0 + ysize, 0.0);
			glEnd();
			xsize += 10.0;
		}
		ysize += 10.0;
	}
	glFlush();
}

int main (int argc, char** argv){

	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_SINGLE | GLUT_RGBA); //establece el modo de visualización
	glutInitWindowSize(500, 500); //tamaño de la ventana
	glutInitWindowPosition(0, 0);
	glutCreateWindow("2048");
	inicializa();
	glutDisplayFunc(dibuja); //envia los gráficos a la ventana de visualizacion
	glutMainLoop(); //espera abierto
	return 0;


}