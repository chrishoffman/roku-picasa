
Function LoadPicasa() As Object
    ' global singleton
    return m.picasa
End Function

Function InitPicasa() As Object
    ' constructor
    this = CreateObject("roAssociativeArray")
    this.protocol = "http"
    this.scope = this.protocol + "://picasaweb.google.com/data"
    this.prefix = this.scope + "/feed/api"
    this.oauth_prefix = "https://www.google.com/accounts"
    this.link_prefix = getLinkWebsite()
    
    this.ExecServerAPI = picasa_exec_api
    
    'Picasa
    this.BrowsePicasa = picasa_browse
    this.BrowseFeatured = picasa_featured
    this.PhotoSearch = picasa_photo_search
    
    'Album
    this.BrowseAlbums = picasa_browse_albums
    this.newAlbumListFromXML = picasa_new_album_list
    this.newAlbumFromXML = picasa_new_album
    this.getAlbumMetaData = picasa_get_album_meta
    this.DisplayAlbum = picasa_display_album

    'Tags
    this.BrowseTags = picasa_browse_tags
    this.newTagListFromXML = picasa_new_tag_list
    this.newTagFromXML = picasa_new_tag
    
    'Favorites
    this.BrowseFavorites = picasa_browse_favorites
    this.DisplayFavorites = picasa_display_favorites
    this.newFavListFromXML = picasa_new_fav_list
    this.getFavMetaData = picasa_get_fav_meta
    
    'Video
    this.BrowseVideos = picasa_browse_videos
    
    this.RandomPhotos = picasa_random_photos
    this.BrowseSettings = picasa_browse_settings
    this.SlideshowSpeed = picasa_set_slideshow_speed
    this.DelinkPlayer = picasa_delink
    this.About = picasa_about
 
    'Set Slideshow Duration
    ssdur=RegRead("SlideshowDuration","Settings")
    if ssdur=invalid then
        this.SlideshowDuration=5
    else
        this.SlideshowDuration=Val(ssdur)
    end if   
    
    print "Picasa: init complete"
    return this
End Function


Function picasa_exec_api(url_stub="" As String, username="default" As Dynamic)
    oa = Oauth()
    
    if username=invalid then
        username=""
    else
        username="user/"+username
    end if
    
    http = NewHttp(m.prefix + "/" + username + url_stub)
    oa.sign(http,true)
    
    xml=http.getToStringWithTimeout(10)
    print xml
    rsp=ParseXML(xml)
    if rsp=invalid then
        ShowErrorDialog("API return invalid. Try again later","Bad response")
    end if
    
    return rsp
End Function

' ********************************************************************
' ********************************************************************
' ***** Picasa
' ***** Picasa
' ********************************************************************
' ********************************************************************
Sub picasa_browse()
	screen=uitkPreShowPosterMenu()

    highlights=m.highlights
    
    menudata=[
        {ShortDescriptionLine1:"Featured", DescriptionLine2:"What's featured now on Picasa", HDPosterUrl:highlights[2], SDPosterUrl:highlights[2]},
        {ShortDescriptionLine1:"Community Search", ShortDescriptionLine2:"Search community photos", HDPosterUrl:highlights[3], SDPosterUrl:highlights[3]},
    ]
    onselect=[0, m, "BrowseFeatured","PhotoSearch"]
    
    uitkDoPosterMenu(menudata, screen, onselect)  

End Sub

Sub picasa_featured()
    rsp=m.ExecServerAPI("featured?max-results=200&v=2.0&fields=entry(title,gphoto:id,media:group(media:description,media:content,media:thumbnail))&thumbsize=220&imgmax=912",invalid)
    if rsp<>invalid then
        featured=picasa_new_image_list(rsp.entry)
        DisplayImageSet(featured, "Featured", 0, m.SlideshowDuration)
    end if
End Sub

Sub picasa_photo_search()
    port=CreateObject("roMessagePort") 
    screen=CreateObject("roSearchScreen")
    screen.SetMessagePort(port)
    
    history=CreateObject("roSearchHistory")
    screen.SetSearchTerms(history.GetAsArray())
    
    screen.Show()
    
    while true
        msg = wait(0, port)
        
        if type(msg) = "roSearchScreenEvent" then
            print "Event: "; msg.GetType(); " msg: "; msg.GetMessage()
            if msg.isScreenClosed() then
                return
            else if msg.isFullResult()
                keyword=msg.GetMessage()
                dialog=ShowPleaseWait("Please wait","Searching images for "+keyword)
                rsp=m.ExecServerAPI("all?kind=photo&q="+keyword+"&max-results=200&v=2.0&fields=entry(title,gphoto:id,media:group(media:description,media:content,media:thumbnail))&thumbsize=220&imgmax=912",invalid)
                images=picasa_new_image_list(rsp.entry)
                dialog.Close()
                if images.Count()>0 then
                    history.Push(keyword)
                    screen.AddSearchTerm(keyword)
                    DisplayImageSet(images, keyword, 0, m.SlideshowDuration)
                else
                    ShowErrorDialog("No images match your search","Search results")
                end if
            else if msg.isCleared() then
                history.Clear()
            end if
        end if
    end while
End Sub

' ********************************************************************
' ********************************************************************
' ***** Albums
' ***** Albums
' ********************************************************************
' ********************************************************************
Sub picasa_browse_albums(username="default", nickname=invalid)    
    breadcrumb_name=""
    if username<>"default" and nickname<>invalid then
        breadcrumb_name=nickname
    end if
    screen=uitkPreShowPosterMenu(breadcrumb_name,"Albums")
    
    rsp=m.ExecServerAPI("?kind=album&v=2.0&fields=entry(title,gphoto:numphotos,gphoto:user,gphoto:id,media:group(media:description,media:thumbnail))",username)
    if not isxmlelement(rsp) then return
    albums=m.newAlbumListFromXML(rsp.entry)
    
    onselect = [1, albums, m, function(albums, picasa, set_idx):picasa.DisplayAlbum(albums[set_idx]):end function]
    uitkDoPosterMenu(picasa_get_album_meta(albums), screen, onselect)
End Sub


Function picasa_new_album_list(xmllist As Object) As Object
    albumlist=CreateObject("roList")
    for each record in xmllist
        album=m.newAlbumFromXML(record)
        if album.GetImageCount() > 0 then
            albumlist.Push(album)
        end if
    next
    
    return albumlist
End Function

Function picasa_new_album(xml As Object) As Object
    album = CreateObject("roAssociativeArray")
    album.picasa=m
    album.xml=xml
    album.GetUsername=function():return m.xml.GetNamedElements("gphoto:user")[0].GetText():end function
    album.GetTitle=function():return m.xml.title[0].GetText():end function
    album.GetID=function():return m.xml.GetNamedElements("gphoto:id")[0].GetText():end function
    album.GetImageCount=function():return Val(m.xml.GetNamedElements("gphoto:numphotos")[0].GetText()):end function
    album.GetThumb=get_thumb
    album.GetImages=album_get_images
    return album
End Function

Function picasa_get_album_meta(albums As Object)
    albummetadata=[]
    for each album in albums
        thumb=album.GetThumb()
        albummetadata.Push({ShortDescriptionLine1: album.GetTitle(), HDPosterUrl: thumb, SDPosterUrl: thumb})
    next
    return albummetadata
End Function

Function album_get_images()
    rsp=m.picasa.ExecServerAPI("/albumid/"+m.GetID()+"?kind=photo&v=2.0&fields=entry(title,gphoto:id,gphoto:videostatus,media:group(media:description,media:content,media:thumbnail))&thumbsize=220&imgmax=912",m.GetUsername())
    if not isxmlelement(rsp) then 
        return invalid
    end if
    
    return picasa_new_image_list(rsp.entry)
End Function

Sub picasa_display_album(album As Object)
    print "DisplayAlbum: init"
    medialist=album.GetImages()
    
    videos=[]
    images=[]
    for each media in medialist
        if media.IsVideo() then
            videos.Push(media)
        else
            images.Push(media)
            print media.GetURL()
        end if
    end for
    
    title=album.GetTitle()
    
    if videos.Count()>0 then        
        if images.Count()>0 then 'Combined photo and photo album
            screen=uitkPreShowPosterMenu("", title)
            
            albummenudata = [
                {ShortDescriptionLine1:Pluralize(images.Count(),"Photo"),
                 HDPosterUrl:images[0].GetThumb(),
                 SDPosterUrl:images[0].GetThumb()},
                {ShortDescriptionLine1:Pluralize(videos.Count(),"Video"),
                 HDPosterUrl:videos[0].GetThumb(),
                 SDPosterUrl:videos[0].GetThumb()},
            ]
            
            onselect = [1, [images, videos], title, album_select]
            uitkDoPosterMenu(albummenudata, screen, onselect)
        else 'Video only album
            picasa_browse_videos(videos, title)
        end if
    else 'Photo only album
        DisplayImageSet(images, title, 0, m.SlideshowDuration)
    end if
End Sub

Sub album_select(media, title, set_idx)
    if set_idx=0 then 
        DisplayImageSet(media[0], title) 
    else 
        picasa_browse_videos(media[1], title)
    end if
End Sub

' ********************************************************************
' ********************************************************************
' ***** Tags
' ***** Tags
' ********************************************************************
' ********************************************************************
Sub picasa_browse_tags(username="default", nickname=invalid)    
    breadcrumb_name=""
    if username<>"default" and nickname<>invalid then
        breadcrumb_name=nickname
    end if
    
    screen=uitkPreShowPosterMenu(breadcrumb_name,"Tags")
    
    rsp=m.ExecServerAPI("?kind=tag&v=2.0&fields=entry(title)",username)
    if not isxmlelement(rsp) then return
    tags=m.newTagListFromXML(rsp.entry, username)
    
    if tags.Count()>0 then
        onselect = [1, tags, m, function(tags, picasa, set_idx):picasa.DisplayAlbum(tags[set_idx]):end function]
        uitkDoPosterMenu(picasa_get_album_meta(tags), screen, onselect)
    else
        uitkDoMessage("No photos have been tagged", screen)
    end if
End Sub

Function picasa_new_tag_list(xmllist As Object, username) As Object
    taglist=CreateObject("roList")
    for each record in xmllist
        tag=m.newTagFromXML(record, username)
        taglist.Push(tag)
    next
    
    return taglist
End Function

Function picasa_new_tag(xml As Object, username) As Object
    tag = CreateObject("roAssociativeArray")
    tag.picasa=m
    tag.xml=xml
    tag.username=username
    tag.GetUsername=function():return m.username:end function
    tag.GetTitle=function():return m.xml.title[0].GetText():end function
    tag.GetThumb=function():return "pkg:/images/icon_s.jpg":end function
    tag.GetImages=tag_get_images
    return tag
End Function

Function tag_get_images()
    rsp=m.picasa.ExecServerAPI("?kind=photo&tag="+m.GetTitle(),m.GetUsername())
    if not isxmlelement(rsp) then 
        return invalid
    end if
    
    return picasa_new_image_list(rsp.entry)
End Function

' ********************************************************************
' ********************************************************************
' ***** Images
' ***** Images
' ********************************************************************
' ********************************************************************
Function picasa_new_image_list(xmllist As Object) As Object
    images=CreateObject("roList")
    for each record in xmllist
        image=picasa_new_image(record)
        if image.GetURL()<>invalid then
            images.Push(image)
        end if
    next
    
    return images
End Function

Function picasa_new_image(xml As Object) As Object
    image = CreateObject("roAssociativeArray")
    image.xml=xml
    image.GetTitle=function():return m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:description")[0].GetText():end function
    image.GetID=function():return m.xml.GetNamedElements("gphoto:id")[0].GetText():end function
    image.GetURL=image_get_url
    image.GetThumb=get_thumb
    image.IsVideo=function():return (m.xml.GetNamedElements("gphoto:videostatus")[0]<>invalid):end function
    image.GetVideoStatus=function():return m.xml.GetNamedElements("gphoto:videostatus")[0].GetText():end function
    return image
End Function

Function image_get_url()
    images=m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:content")
    if m.IsVideo() then
        if m.GetVideoStatus()="final" or m.GetVideoStatus()="ready" then
            for each image in images
                if image.GetAttributes()["type"]="video/mpeg4" then
                    return image.GetAttributes()["url"]
                end if
            end for
        end if
    else
        if images[0]<>invalid then
            return images[0].GetAttributes()["url"]
        end if
    end if
    
    return invalid
End Function

Function images_get_meta(images As Object)
    imagemetadata=[]
    for each image in images
        imagemetadata.Push({ShortDescriptionLine1: image.GetTitle(), HDPosterUrl: image.GetThumb(), SDPosterUrl: image.GetThumb()})
    next
    return imagemetadata
End Function

Function get_thumb()
    if m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail").Count()>0 then
        return m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")[0].GetAttributes()["url"]
    end if
    
    return "pkg:/images/icon_s.jpg"
End Function

' ********************************************************************
' ********************************************************************
' ***** Favorites
' ***** Favorites
' ********************************************************************
' ********************************************************************
Sub picasa_browse_favorites(username="default", nickname=invalid)
    breadcrumb_name=""
    if username<>"default" and nickname<>invalid then
        breadcrumb_name=nickname
    end if
    
    screen=uitkPreShowPosterMenu(breadcrumb_name,"Favorites")
    
    rsp=m.ExecServerAPI("/contacts?kind=user",username)
    if not isxmlelement(rsp) then return
    favs=picasa_new_fav_list(rsp.entry)
    
    if favs.Count() > 0 then
        onselect = [1, favs, m, function(ff, picasa, set_idx):picasa.DisplayFavorites(ff[set_idx]):end function]
        uitkDoPosterMenu(m.getFavMetaData(favs), screen, onselect)
    else
        uitkDoMessage("You do not have any favorites", screen)
    end if
End Sub

Sub picasa_display_favorites(fav As Object)
    user=fav.GetUser()
    nickname=fav.GetNickname()
    
    screen=uitkPreShowPosterMenu("",nickname)
    
    'Get highlights from recent photo feed
    highlights=[]
    rsp=m.ExecServerAPI("?kind=photo&max-results=5&v=2.0&fields=entry(media:group(media:description,media:content,media:thumbnail))&thumbsize=220&imgmax=912",user)
    if isxmlelement(rsp) then 
        images=picasa_new_image_list(rsp.entry)
        for each image in images
            highlights.Push(image.GetThumb())
        end for
    end if
    
    for i=0 to 3
        if highlights[i]=invalid then
            highlights[i]="pkg:/images/icon_s.jpg"
        end if
    end for
    
    menudata = [
        {ShortDescriptionLine1:"Albums", ShortDescriptionLine2:"Browse Recently Updated Albums", HDPosterUrl:highlights[0], SDPosterUrl:highlights[0]},
        {ShortDescriptionLine1:"Tags", ShortDescriptionLine2:"Browse Tags", HDPosterUrl:highlights[1], SDPosterUrl:highlights[1]},
        {ShortDescriptionLine1:"Favorites", ShortDescriptionLine2:"Browse Favorites", HDPosterUrl:highlights[2], SDPosterUrl:highlights[2]},
        {ShortDescriptionLine1:"Random Photos", ShortDescriptionLine2:"Display slideshow of random photos", HDPosterUrl:highlights[3], SDPosterUrl:highlights[3]},
    ]
	
	onclick=[0, m, ["BrowseAlbums", user, nickname], ["BrowseTags", user, nickname], ["BrowseFavorites", user, nickname], ["RandomPhotos", user]]
    
	uitkDoPosterMenu(menudata, screen, onclick)
End Sub

Function picasa_new_fav_list(xmllist As Object)
    favs=[]
    for each record in xmllist
        fav = CreateObject("roAssociativeArray")
        fav.xml=record
        fav.GetUser=function():return m.xml.GetNamedElements("gphoto:user")[0].GetText():end function
        fav.GetNickname=function():return m.xml.GetNamedElements("gphoto:nickname")[0].GetText():end function
        fav.GetThumb=function():return m.xml.GetNamedElements("gphoto:thumbnail")[0].GetText():end function
        fav.GetURL=function():return m.xml.author.uri[0].GetText():end function
        favs.Push(fav)
    end for
    
    return favs
End Function

Function picasa_get_fav_meta(fav As Object)
    favmetadata=[]
    for each f in fav
        favmetadata.Push({ShortDescriptionLine1: f.GetNickname(), ShortDescriptionLine2: f.GetURL(), HDPosterUrl: f.GetThumb(), SDPosterUrl: f.GetThumb()})
    next
    
    return favmetadata
End Function

' ********************************************************************
' ********************************************************************
' ***** Random Slideshow
' ***** Random Slideshow
' ********************************************************************
' ********************************************************************
Sub picasa_random_photos(username="default")
    ss=PrepDisplaySlideShow()
    
    rsp=m.ExecServerAPI("?kind=album&v=2.0&fields=entry(title,gphoto:numphotos,gphoto:user,gphoto:id,media:group(media:description,media:thumbnail))",username)
    if not isxmlelement(rsp) then return
    albums=m.newAlbumListFromXML(rsp.entry)
    
    ss.SetPeriod(m.SlideshowDuration)
    port=ss.GetMessagePort()
    
    image_univ=[]
    for i=0 to albums.Count()-1
        image_count=albums[i].GetImageCount()
        for j=0 to image_count-1
            image_univ.Push([i,j])
        end for
    end for
    
    album_cache={}
    album_skip={}
    while true
        next_image:
        'Select image from total universe
        selected_idx=Rnd(image_univ.Count())-1
        
        'Caching image lookup results, saves us some API calls
        album_idx=image_univ[selected_idx][0]
        
        'Skip if passworded
        if album_skip.DoesExist(itostr(album_idx)) then goto next_image
        
        if album_cache.DoesExist(itostr(album_idx)) then
            imagelist=album_cache.Lookup(itostr(album_idx))
        else
            imagelist=albums[album_idx].GetImages()
            if imagelist=invalid then 
                album_skip.AddReplace(itostr(album_idx),1)
                goto next_image
            end if
            album_cache.AddReplace(itostr(album_idx), imagelist)
        end if
        
        image_idx=image_univ[selected_idx][1]
        image=imagelist[image_idx]
        
        if image<>invalid then
            image.Info={}
            image.Info.TextOverlayUL="Album: "+albums[album_idx].GetTitle()
            
            imagelist=[image]
            
            AddNextimageToSlideShow(ss, imagelist, 0)
            while true
                msg = port.GetMessage()
                if msg=invalid then exit while
                if ProcessSlideShowEvent(ss, msg, imagelist) then return
            end while
            
            'Sleeping for Slideshow Duration - 2.5 seconds
            sleep((m.SlideshowDuration-2.5)*1000)
        end if
    end while
End Sub

Sub BrowseImages(images AS Object, title="" As String)
    screen=uitkPreShowPosterMenu(title,"Photos")
    
    while true
        selected=uitkDoPosterMenu(images_get_meta(images), screen)
        if selected>-1 then
            DisplayImageSet(images, title, selected, m.picasa.SlideshowDuration)
        else
            return
        end if
    end while
End Sub

' ********************************************************************
' ********************************************************************
' ***** Videos
' ***** Videos
' ********************************************************************
' ********************************************************************
Sub picasa_browse_videos(videos As Object, title As String)
    if videos.Count()=1 then
        DisplayVideo(GetVideoMetaData(videos)[0])
    else
        screen=uitkPreShowPosterMenu(title,"Videos")
        metadata=GetVideoMetaData(videos)
        
        onselect = [1, metadata, m, function(video, picasa, set_idx):DisplayVideo(video[set_idx]):end function]
        uitkDoPosterMenu(metadata, screen, onselect)
    end if
End Sub

Function GetVideoMetaData(videos As Object)
    metadata=[]
    
    res=[480]
    bitrates=[1000]
    qualities=["SD"]
    
    for each video in videos
        meta=CreateObject("roAssociativeArray")
        meta.ContentType="movie"
        meta.Title=video.GetTitle()
        meta.ShortDescriptionLine1=meta.Title
        meta.SDPosterUrl=video.GetThumb()
        meta.HDPosterUrl=video.GetThumb()
        meta.StreamBitrates=bitrates
        meta.StreamQualities=qualities
        meta.StreamFormat="mp4"
        
        meta.StreamBitrates=[]
        meta.StreamQualities=[]
        meta.StreamUrls=[]
        for i=0 to res.Count()-1
            url=video.GetURL()
            if url<>invalid then
                meta.StreamUrls.Push(url)
                meta.StreamBitrates.Push(bitrates[i])
                meta.StreamQualities.Push(qualities[i])
                if res[i]>960 then
                    meta.IsHD=True
                    meta.HDBranded=True
                end if
            end if
        end for
        
        metadata.Push(meta)
    end for
    
    return metadata
End Function


Function DisplayVideo(content As Object)
    print "Displaying video: "
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    
    video.SetContent(content)
    video.show()
    
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                print "Closing video screen"
                video.Close()
                exit while
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
End Function
