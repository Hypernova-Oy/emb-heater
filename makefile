programName=emb-heater
confDir=etc/$(programName)
systemdServiceDir=etc/systemd/system
systemPath=/usr/local/bin
logPath=/var/log/$(programName)


#Macro to check the exit code of a make expression and possibly not fail on warnings
RC      := test $$? -lt 100 


build: compile

restart: serviceEnable

install: build configure perlDeploy scriptsLink serviceEnable

perlDeploy:
	./Build installdeps
	./Build install

compile:
	#Build Perl modules
	perl Build.PL
	./Build

test:
	prove -Ilib -I. t/*.t

configure:
	mkdir -p /$(confDir)
	cp $(confDir)/daemon.conf /$(confDir)/daemon.conf

	cp $(systemdServiceDir)/$(programName).service /$(systemdServiceDir)/$(programName).service

	mkdir -p $(logPath)

	grep 'dtoverlay=w1-gpio' /boot/config.txt || \
	( echo "dtoverlay=w1-gpio" >> /boot/config.txt && echo "" && echo "" && echo "1 Wire device activated in /boot/config.txt" && echo "You must reboot for changes to take effect" && echo "" && echo "" )

unconfigure:
	rm -r /$(confDir) || $(RC)
	rm -r $(logPath) || $(RC)

serviceEnable:
	systemctl daemon-reload
	systemctl enable $(programName)
	systemctl start $(programName)

serviceDisable:
	systemctl stop $(programName)
	rm /$(systemdServiceDir)/$(programName).service
	systemctl daemon-reload

scriptsLink:
	cp scripts/heater $(systemPath)/

scriptsUnlink:
	rm $(systemPath)/heater

clean:
	./Build realclean

uninstall: serviceDisable unconfigure scriptsUnlink clean

