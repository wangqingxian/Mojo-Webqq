package Mojo::Webqq::Model::Ext;
BEGIN{
    eval{
        require Webqq::Encryption;
    };
    unless($@){
        $Mojo::Webqq::Model::Ext::has_webqq_encryption = 1;
    }
}
our $_retcode;
our $_verifycode;
our $_md5_salt;
our $_verifysession;
our $_is_rand_salt;
our $_api_check_sig;

sub model_ext_authorize{
    my $self = shift;
    if(not $Mojo::Webqq::Model::Ext::has_webqq_encryption){
        $self->warn("未安装 Webqq::Encryption 模块，无法获取扩展信息，安装方法参见: https://metacpan.org/pod/distribution/Webqq-Encryption/lib/Webqq/Encryption.pod");
        $self->model_ext(0);
        return;
    } 
    if($self->uid and $self->pwd){
        $self->info("开始扩展信息授权...");
        my $ret = $self->_model_ext_prepare() && $self->_model_ext_check() && $self->_model_ext_login() && $self->_model_ext_check_sig();
        if($ret){
            $self->info("扩展信息授权成功");
        }
        else{
            $self->info("扩展信息授权失败，无法获取扩展信息");
        }
        $self->model_ext($ret);
    }
    else{
        $self->warn("未设置账号授权密码，无法获取扩展信息，已忽略");
    }
}
sub _model_ext_prepare {
    my $self = shift;
    $self->debug("扩展信息授权中(prepare)...");
    my(undef,$ua,$tx) = $self->http_get('https://xui.ptlogin2.qq.com/cgi-bin/xlogin?appid=715030901&daid=73&pt_no_auth=1&s_url=http%3A%2F%2Fqun.qq.com%2F',{Referer=>'http://qun.qq.com/',ua_debug_res_body=>0, blocking=> 1});
    return $tx->res->code == 200?1:0;
}

sub _model_ext_check {
    my $self = shift;
    $self->debug("扩展信息授权中(check)...");
    my $content = $self->http_get(
        $self->gen_url('https://ssl.ptlogin2.qq.com/check',
            (
                regmaster => '',
                pt_tea    => 2,
                pt_vcode  => 1,
                uin       => $self->uid,
                appid     => 715030901,
                js_ver    => 10233,
                js_type   => 1,
                login_sig => $self->search_cookie("pt_login_sig"),
                u1        => 'http%3A%2F%2Fqun.qq.com%2F',
                r         => rand(),
                pt_uistyle=> 40,
                pt_jstoken=> 485008785
            )
        ),
        {blocking=>1,Referer => 'https://xui.ptlogin2.qq.com/cgi-bin/xlogin?appid=715030901&daid=73&pt_no_auth=1&s_url=http%3A%2F%2Fqun.qq.com%2F'},
    );
    my($retcode,$verifycode,$md5_salt,$verifysession,$is_rand_salt) = $content =~/'([^']*)'/g;

    if($retcode == 0 ){
        $_retcode = $retcode;
        $_verifycode = $verifycode;
        $_md5_salt = $md5_salt;
        $_verifysession = $verifysession;
        $_is_rand_salt = $is_rand_salt;
    }
    else{
        $self->error("群扩展信息授权失败: 可能因为登录环境变化引起，解决方法参见：https://github.com/sjdy521/Mojo-Webqq/issues/183"); 
    }
    return $retcode == 0? 1 : 0;
}

sub _model_ext_login{
    my $self = shift;
    $self->debug("扩展信息授权中(login)...");
    my $content = $self->http_get(
        $self->gen_url('https://ssl.ptlogin2.qq.com/login',
            (
                u  => $self->uid,
                verifycode => $_verifycode,
                pt_vcode_v1 => 0,
                pt_verifysession_v1 => ,$_verifysession // $self->search_cookie('verifysession'),
                p  => Webqq::Encryption::pwd_encrypt($self->pwd,$_md5_salt,$_verifycode,1),
                pt_randsalt => $_is_rand_salt || 0,,
                pt_jstoken  => 485008785,
                u1          => 'http%3A%2F%2Fqun.qq.com%2F',
                ptredirect  => 1,
                h           => 1,
                t           => 1,
                g           => 1,
                from_ui     => 1,
                ptlang      => 2052,
                action      => '1-14-1515074375763',
                js_ver      => 10233,
                js_type     => 1,
                login_sig   => $self->search_cookie("pt_login_sig"),
                pt_uistyle  => 40,
                aid         => 715030901,
                daid        => 73,
                has_onekey  => 1,
            )
        ) . '&',
        {
            Referer => 'https://xui.ptlogin2.qq.com/cgi-bin/xlogin?appid=715030901&daid=73&pt_no_auth=1&s_url=http%3A%2F%2Fqun.qq.com%2F',
            blocking => 1,
        },
    );

    my($retcode,undef,$api_check_sig,undef,$info,$nick) = $content =~/'([^']*)'/g;
    if($retcode != 0){
        $self->warn("扩展信息授权失败: $info");
    }
    else{
        $_api_check_sig = $api_check_sig;
    }
    return $retcode == 0?1:0;
}

sub _model_ext_check_sig {
    my $self = shift;
    $self->debug("扩展信息授权中(check_sig)...");
    my(undef,$ua,$tx) = $self->http_get($_api_check_sig);
    return $tx->res->code == 200?1:0;
}

1;
