<footer class="post-footer"> 原有内容
<div>    
 {# 此处判断是否在索引列表中 #}
 {% if not is_index %}
<ul class="post-copyright">
  <li class="post-copyright-author">
      <strong>本文作者：</strong>{{ theme.author }}
  </li>
  <li class="post-copyright-link">
    <strong>本文链接：</strong>
    <a href="{{ url_for(page.path) }}" title="{{ page.title }}">{{ page.path }}</a>
  </li>
  <li class="post-copyright-license">
    <strong>版权： </strong>
    本站文章均采用 <a href="http://creativecommons.org/licenses/by-nc-sa/3.0/cn/" rel="external nofollow" target="_blank">CC BY-NC-SA 3.0 CN</a> 许可协议，请勿用于商业，转载注明出处！
  </li>
</ul>
{% endif %}
</div>