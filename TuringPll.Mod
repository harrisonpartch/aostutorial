MODULE TuringPll;

IMPORT
	Kernel, Raster, Random, Objects, WMRectangles, WMGraphics, Modules, Strings,
	WM := WMWindowManager, Out:=KernelLog;

CONST
	M = 200; 
	SZE = 2;
	
TYPE TEngine=OBJECT
VAR
	istart, iend: INTEGER;
	
PROCEDURE & init(n,m: INTEGER);
BEGIN
	istart:=n;
	iend:=m;
END init;

PROCEDURE go;
BEGIN{EXCLUSIVE}
	GO:=TRUE
END go;

PROCEDURE tick;
VAR i, j : INTEGER;
	a,b: REAL;
BEGIN
	FOR i := istart TO iend DO
		FOR j := 1 TO M - 2 DO
			n1[i, j] := mesh1[i - 1, j] + mesh1[i + 1, j] + mesh1[i, j - 1] + mesh1[i, j + 1]
				+ mesh1[i - 1, j - 1] +  mesh1[i + 1, j + 1] + mesh1[i + 1, j - 1] + mesh1[i - 1, j + 1]
		END
	END;
	FOR i := istart TO iend DO
		a:=i/M;
		FOR j := 1 TO M - 2 DO
			b:=j/M;
			(*  HERE ARE THE DIFFERENCE RULES! *)
			mesh1[i, j] := mesh1[i, j] + a*n1[i, j]/180- b*(mesh2[i, j] * mesh2[i, j])  ;
			mesh2[i, j] := (mesh2[i, j] +  mesh1[i, j]/20) - 0.03 ;
			IF mesh1[i, j] < 0 THEN mesh1[i, j] := 0 END;
			IF mesh2[i, j] < 0 THEN mesh2[i, j] := 0 END;

		END;
	END;
END tick;

BEGIN{ACTIVE, PRIORITY(Objects.Low)}
	REPEAT	
		BEGIN {EXCLUSIVE} 	
			AWAIT(GO);
			GO:=FALSE;
		END;
		tick;		
	UNTIL FALSE
END TEngine;

TYPE TWindow* =  OBJECT(WM.BufferWindow)
VAR
	alive, dead, pause: BOOLEAN;
	i : INTEGER;
	TD: INTEGER;
		
PROCEDURE KeyEvent (ucs : INTEGER; flags : SET; keysym : INTEGER);
BEGIN
	CASE CHR(ucs) OF
		| 'q': Close
		| 'p': pll:=~pll
		| ' ': pause:=~pause
	ELSE
	END
END KeyEvent;

PROCEDURE &New*;
VAR 
	i, j : INTEGER;
	tsize, tc: INTEGER;
BEGIN
	Init(M*SZE, M*SZE, FALSE);
	manager := WM.GetDefaultManager();
	manager.Add(100, 100, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing});
	SetTitle(Strings.NewString("TuringPll Tutorial For Lac"));
	SetIcon(WMGraphics.LoadImage("WMIcons.tar://TuringCoatWnd.png", TRUE));
	FOR i := 0 TO M - 1 DO
		FOR j := 0 TO M - 1 DO
			mesh1[i, j] := 0;
			mesh2[i, j] := 0;
			n1[i, j] := 0
		END
	END;
	FOR i :=  1 TO M - 2 DO
		FOR j := 1 TO M - 2 DO
			IF random.Dice(100) > 90 THEN mesh1[i, j] := random.Dice(1000)/1000 END
		END
	END;
	tsize := i DIV 20;
	tc:=0;
	FOR i :=  0 TO 19 DO
		NEW(te[i],tc+1,tc+tsize);	
		tc:=tc+tsize;
	END;	
END New;

PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : INTEGER);
BEGIN
	Draw^(canvas, w, h, 0)
END Draw;

PROCEDURE Close;
BEGIN
	alive := FALSE;
	BEGIN {EXCLUSIVE} AWAIT(dead); END;
	Close^;
END Close;

PROCEDURE Generation;
VAR i, j : INTEGER;
	a,b: REAL;
BEGIN
(* Calculate neighborhoods on the borders of the mesh. The interior is calculated in the parallel engines *)
	FOR i := 1 TO M - 2 DO
		n1[i, 0] := mesh1[i - 1, 0] + mesh1[i + 1, 0] + mesh1[i, M - 1] + mesh1[i, 1]
		 	+ mesh1[i - 1, M - 1] +  mesh1[i + 1, 1] + mesh1[i + 1, M - 1] + mesh1[i - 1,  1];
		n1[i, M - 1] := mesh1[i - 1, M - 1] + mesh1[i + 1, M - 1] + mesh1[i, M - 2] + mesh1[i, 0]
			+ mesh1[i - 1, M - 2] +  mesh1[i + 1, 0] + mesh1[i + 1, M - 2] + mesh1[i - 1, 0];
		END;
	FOR j := 1 TO M - 2 DO
		n1[0, j] := mesh1[M - 1, j] + mesh1[1, j] + mesh1[0, j - 1] + mesh1[0, j + 1]
			+ mesh1[M - 1, j - 1] +  mesh1[1, j + 1] + mesh1[1, j - 1] + mesh1[M - 1, j + 1];
		n1[M - 1, j] := mesh1[M - 2, j] + mesh1[0, j] + mesh1[M - 1, j - 1] + mesh1[M - 1, j + 1]
			+ mesh1[M - 2, j - 1] +  mesh1[0, j + 1] + mesh1[0, j - 1] + mesh1[M - 2, j + 1]
	END;
(*	BEGIN {EXCLUSIVE} TD:=0 END; *)
	IF pll THEN 
		FOR i :=  0 TO 19 DO
			te[i].go;
		END;			
	ELSE
		FOR i :=  0 TO 19 DO
			te[i].tick;
		END;				
	END 
END Generation;

PROCEDURE DrawIt;
VAR i, j, ix, jy : INTEGER;
	pix : Raster.Pixel;
	mode : Raster.Mode;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	FOR i := 0 TO M - 1 DO
		ix := i * SZE;
		FOR j := 0 TO M - 1 DO
			jy := j * SZE;
			Raster.SetRGB(pix, SHORT((255-ENTIER(mesh1[i, j] * 255)) ), SHORT((255-ENTIER(mesh2[i, j] * 255)) ), SHORT((255-ENTIER(mesh1[i, j] * 255))));
			Raster.Fill(img, ix, jy, ix+SZE, jy+SZE, pix, mode)
		END
	END;
	Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
END DrawIt;

BEGIN {ACTIVE}
	alive := TRUE;
	Objects.SetPriority(Objects.High);
	WHILE alive DO 
		IF ~pause THEN
	(*		Kernel.SetTimer(timer,1000); *)
			Generation;
		(*	dt:=Kernel.Elapsed(timer);
			Out.Int(dt,0);
			Out.Ln; *)
			DrawIt;
		ELSE
			Objects.Sleep(100);
		END
	END;
	BEGIN {EXCLUSIVE} dead := TRUE; END;
END TWindow;

VAR
	mesh1, mesh2, n1 : ARRAY M,M OF REAL;
	tw: TWindow;
	random : Random.Generator;
	timer: Kernel.MilliTimer;
	dt: INTEGER;
	te: ARRAY 20 OF TEngine;
	pll: BOOLEAN;
	GO: BOOLEAN;
	
PROCEDURE Open*;
BEGIN
	NEW(tw);
END Open;

PROCEDURE Close*;
BEGIN
	IF tw#NIL THEN tw.Close; tw:=NIL END;
END Close;

BEGIN
	Modules.InstallTermHandler(Close);
	NEW(random);
END TuringPll.

The compiler stops at the period after "END TuringPII": often we put tools and comments down here.

When you change the code and recompile it, you are generating a new object file; but the old object code 
is in memory already and the new code will not be loaded until you free the old module:

SystemTools.Free TuringPll ~

and load the new one:

TuringPll.Open ~



q to quit
space to pause
p to (de)parallelize


