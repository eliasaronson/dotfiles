git config --global alias.co checkout
git config --global alias.br branch

git config --global alias.ci commit
git config --global --replace-all alias.cia "commit --amend"
git config --global --replace-all alias.cin "commit --no-verify"
git config --global --replace-all alias.cian "commit --amend --no-verify"

git config --global alias.st status
git config --global alias.wc whatchanged

git config --global alias.df diff

git config --global alias.d pull
git config --global alias.u push
git config --global --replace-all alias.un "push --no-verify"
git config --global --replace-all alias.uf "push --force-with-lease"

git config --global alias.cp cherry-pick

git config --global alias.sw show

git config --global --replace-all alias.rs "restore --staged"
git config --global alias.re restore

git config --global alias.rb rebase
git config --global --replace-all alias.rbc "rebase --continue"
git config --global --replace-all alias.rba "rebase --abort"

git config --global alias.a add
git config --global --replace-all alias.ad 'add -i'
git config --global --replace-all alias.ap 'add -p'
git config --global --replace-all alias.au 'add -u'
git config --global --replace-all alias.ac '!git add -u && git commit'
git config --global --replace-all alias.acp '!git add -u && git commit && git push'

git config --global alias.sh stash
git config --global --replace-all alias.shp 'stash push'

git config --global --add --bool push.autoSetupRemote true
