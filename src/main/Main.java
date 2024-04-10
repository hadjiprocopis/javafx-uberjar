package com.heroapps.MyExampleApp;

import javafx.application.Application;
import javafx.stage.Stage;
import javafx.scene.Scene;
import javafx.scene.Node;
import javafx.scene.control.Label;
import javafx.scene.layout.VBox;
import javafx.scene.control.Button;
import javafx.geometry.Pos;

import java.util.Map;
import java.util.HashMap;
import java.util.Locale;

import org.apache.commons.cli.*;

public class Main extends Application {

	@Override
	public void start(
		Stage stage
	) throws Exception {
		Map<String, String> opts = new HashMap<>();

		Options options = new Options();
		options.addOption("p", "parameter1", true, "CLI param 1");
		options.addOption("o", "option1", false, "CLI option 1");
		options.addOption("v", "verbose", true, "Set the verbosity level, default is zero.");
		options.addOption("D", "dbdir", true, "Set the database dir.");
		options.addOption("9", "dry-run", false, "Exits immediately doing nothing.");

		CommandLineParser parser = new DefaultParser(); // GnuParser has been deprecated
		try {
			CommandLine cmd = parser.parse(options, getParameters().getRaw().toArray(new String[0]));
			System.out.println("cmd line args:");
			for(Option s : cmd.getOptions()){
				// value will be null if it has no value
				// there is also getValues() which concatenates
				// all params to this option into a string
				opts.put(s.getLongOpt(), s.getValue());
				System.out.println(s.getLongOpt()+" : "+(s.getValue()==null?"<null>":s.getValue()));
			}
		} catch (ParseException e) {
			System.err.println("Error: " + e.getMessage());
			System.exit(1);
		}
		System.out.println("Called with this cli parameters (raw): "+getParameters().getRaw());
		if( opts.containsKey("dry-run") ){
			System.out.println("this is a dry-run, exiting now.");
			System.exit(0);
		}

		VBox box = new VBox();
		box.setSpacing(30);
		box.setAlignment(Pos.CENTER);
		Button b = new Button("Bye");
		b.setOnMousePressed(e->{
			((Stage )((Node )e.getSource()).getScene().getWindow()).close();
		});
		/* from https://github.com/openjfx/samples/blob/master/HelloFX/CLI/hellofx/HelloFX.java */
		String javaVersion = System.getProperty("java.version");
		String javafxVersion = System.getProperty("javafx.version");
		Label l1 = new Label("Hello, JavaFX " + javafxVersion + ", running on Java " + javaVersion + ".");
		Label l2 = new Label("They all said hello but they meant goodbye and they didn't like it.");
		box.getChildren().addAll(l1, l2, b);
		Scene scene = new Scene(box, 640, 480);
		stage.setScene(scene);
		stage.show();
	}

	public static void main(
		String[] args
	) throws Exception {
		launch(args);
	}
}
