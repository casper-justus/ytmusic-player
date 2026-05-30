package com.ytmusic.player.ui.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.ytmusic.player.R
import com.ytmusic.player.YTMusicApp
import com.ytmusic.player.data.model.Section
import com.ytmusic.player.ui.adapters.HomeAdapter
import kotlinx.coroutines.launch

class HomeFragment : Fragment() {

    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: HomeAdapter
    private lateinit var loadingView: View
    private lateinit var errorView: View

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_home, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        recyclerView = view.findViewById(R.id.home_recycler)
        loadingView = view.findViewById(R.id.home_loading)
        errorView = view.findViewById(R.id.home_error)

        adapter = HomeAdapter()
        recyclerView.layoutManager = LinearLayoutManager(context)
        recyclerView.adapter = adapter

        loadHome()
    }

    private fun loadHome() {
        loadingView.visibility = View.VISIBLE
        errorView.visibility = View.GONE

        lifecycleScope.launch {
            val repo = YTMusicApp.instance.musicRepository
            repo.getHomeSections().fold(
                onSuccess = { sections ->
                    loadingView.visibility = View.GONE
                    adapter.submitList(sections)
                },
                onFailure = { error ->
                    loadingView.visibility = View.GONE
                    errorView.visibility = View.VISIBLE
                }
            )
        }
    }
}
