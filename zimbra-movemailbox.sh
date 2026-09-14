#!/bin/bash
# V1 Set mailbox quota unlimited dulu, setelah dimigrasi baru di set sesuai cos nya 

DOMAIN="";
FILELISTACCOUNT="/tmp/listmove";
SOURCEMAILBOXIP="";
SOURCEADMIN=""
SOURCEPASSWORD=""
DESTINATIONMAILBOXIP=""
DESTINATIONADMIN=""
DESTINATIONPASSWORD=""
PASSWORDLDAP=""
HOSTNAMEMAILBOXDESTINATION=""

for move in `cat $FILELISTACCOUNT`;
        do
                echo "Starting Move Mailbox $move ....."
                echo "Backuping Signature $move ...."

                zmprov ga $move zimbraPrefMailSignatureHTML > tmp/signature;
                sed -i -e "1d" tmp/signature ;
                sed 's/zimbraPrefMailSignatureHTML: //g' tmp/signature > signature/$move.signature ;
                rm -rf tmp/signature;
                `zmprov ga $move zimbraSignatureName > tmp/name` ;
                sed -i -e "1d" tmp/name ;
                sed 's/zimbraSignatureName: //g' tmp/name > signature/$move.name ;
                rm -rf tmp/name ;

                echo "Backuping Filter $move .... "

                zmprov ga $move zimbraMailSieveScript > tmp/filter
                sed -i -e "1d" tmp/filter
                sed 's/zimbraMailSieveScript: //g' tmp/filter  > filter/$move.filter
                rm -f tmp/filter

                echo "Getting Contact Information $move ...."
                displayName=`zmprov ga $move displayName |grep -i displayName |cut -d ":" -f2 | sed 's/^ *//g' | sed 's/ *$//g'`
                givenName=`zmprov ga $move givenName |grep -i givenName |cut -d ":" -f2 | tr -d " \t\n\r"`
                initials=`zmprov ga $move initials |grep -i initials |cut -d ":" -f2 | tr -d " \t\n\r"`
                sn=`zmprov ga $move sn |grep -i sn |cut -d ":" -f2 | tr -d " \t\n\r"`
                description=`zmprov ga $move sn |grep -i description |cut -d ":" -f2 | tr -d " \t\n\r"`
                zimbraCOSid=`zmprov ga $move zimbraCOSid |grep -i zimbraCOSid |cut -d ":" -f2 | tr -d " \t\n\r"`
                zimbraIsAdminAccount=`zmprov ga $move zimbraIsAdminAccount |grep -i zimbraIsAdminAccount |cut -d ":" -f2 | tr -d " \t\n\r"`
                echo "Getting Mail Forwarding Address $move ...."
                emailforward=`zmprov ga $move zimbraMailForwardingAddress |grep -i zimbraMailForwardingAddress |cut -d ":" -f2 | tr -d " \t\r" > tmp/mailforward`
                echo "Getting Member of Distribution List $move ...."
                memberof=`ldapsearch -x -H 'ldap://'$SOURCEMAILBOXIP'' -D 'uid=zimbra,cn=admins,cn=zimbra' '(&(objectClass=zimbraDistributionList)(zimbraMailForwardingAddress='$move@$DOMAIN'))' zimbraMailAlias -w $PASSWORDLDAP |grep zimbraMailAlias: |cut -d ':' -f2 | tr -d " \t\r" > tmp/memberof`

                echo "Create Account New $move.move on Mailbox 4 ...."
                zmprov ca $move.move@$DOMAIN DefaultPasswordQAZXSW zimbraMailhost $HOSTNAMEMAILBOXDESTINATION
                echo "Modify Account New $move.move ...."
                zmprov ma $move.move displayname "$displayName" givenName "$givenName" initials "$initials" sn "$sn" description "$description" zimbraMailQuota "0" zimbraCOSid "$zimbraCOSid" zimbraHideInGal TRUE
                echo "Set Admin If Account is Admin ...."
                zmprov ma $move.move zimbraIsAdminAccount $zimbraIsAdminAccount
                echo "Adding Email Forwarding $move.move if Any ...."
                for forward in `cat tmp/mailforward`;
                do
                        zmprov ma $move.move +zimbraMailForwardingAddress $forward
                done

                echo "Adding $move.move to Distribution List if Any ...."
                for distlist in `cat tmp/memberof`;
                do
                        zmprov adlm $distlist $move.move@$DOMAIN
                done

                echo "Restore Filter To $move.move ...."
                zmprov ma $move.move zimbraMailSieveScript "`cat filter/$move.filter`"

                echo "Restore Signature To $move.move ...."
                zmprov ma $move.move zimbraSignatureName "`cat signature/$move.name`";
                zmprov ma $move.move zimbraPrefMailSignatureHTML "`cat signature/$move.signature`";
                zmprov ga $move.move zimbraSignatureId > tmp/firmaid; sed -i -e "1d" tmp/firmaid;
                firmaid=`sed 's/zimbraSignatureId: //g' tmp/firmaid`;
                zmprov ma $move.move zimbraPrefDefaultSignatureId "$firmaid";
                zmprov ma $move.move zimbraPrefForwardReplySignatureId "$firmaid";
                rm -rf tmp/firmaid;

                echo "Download Mailbox $move ...."
                curl -k -u admin.mbx3:BLjoqo1abuFlyiKlsT33 https://$SOURCEMAILBOXIP:7071/service/home/$move@$DOMAIN/?fmt=tgz > tmp/$move@$DOMAIN.tgz

                echo "Upload Mailbox $move To $move.move ...."
                curl -k -H "Transfer-Encoding: chunked" -u $SOURCEADMIN:$SOURCEPASSWORD -T tmp/$move@$DOMAIN.tgz -X POST "https://$DESTINATIONMAILBOXIP:7071/service/home/$move.move@$DOMAIN/?fmt=tgz&resolve=skip" && rm -rf tmp/$move@$DOMAIN.tgz

                echo "Renaming Account From $move.move To $move.backup ...."
                yes y | zmprov ra $move@$DOMAIN $move.backup@$DOMAIN
                zmprov ma $move.backup@$DOMAIN zimbraHideInGal TRUE
                yes y | zmprov ra $move.move@$DOMAIN $move@$DOMAIN
                zmprov ma $move@$DOMAIN zimbraHideInGal FALSE
		
		echo "Set Mailbox Quota $move.backup@$DOMAIN To Unlimited"
		zmprov ma $move.backup@$DOMAIN zimbraMailQuota "0"

                echo "Finalize Mailbox .... "
                curl -k -u $SOURCEADMIN:$SOURCEPASSWORD https://$SOURCEMAILBOXIP:7071/service/home/$move.backup@$DOMAIN/?fmt=tgz > tmp/$move.backup@$DOMAIN.tgz
                curl -k -H "Transfer-Encoding: chunked" -u $DESTINATIONADMIN:$DESTINATIONPASSWORD -T tmp/$move.backup@$DOMAIN.tgz -X POST "https://$DESTINATIONMAILBOXIP:7071/service/home/$move@$DOMAIN/?fmt=tgz&resolve=skip" && rm -rf tmp/$move.backup@$DOMAIN.tgz
                echo "Unset Unlimited Quota mailbox $move"
		zmprov ma $move@$DOMAIN zimbraMailQuota ""
		zmprov ma $move.backup@$DOMAIN zimbraMailQuota ""
		echo " ==== SELESAI ===="
                echo ""
                echo ""
                echo ""
        done
